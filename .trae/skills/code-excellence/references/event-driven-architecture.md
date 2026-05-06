# Event-Driven Architecture — 架构级参考

## Purpose

本参考涵盖事件驱动架构中的 5 个核心模式，面向架构师级系统设计。每个模式包含使用场景、常见错误实现、专家级实现方案以及关键洞察。主语言为 Java / Spring / Kafka。

---

## ED-1: Event Sourcing（事件溯源）

**模式描述**：将聚合的状态变更建模为不可变事件序列，以事件流而非当前快照作为事实来源。通过重放事件即可重建任意时刻的状态。

**Use when**：
- 需要完整的审计日志（金融、合规、医疗）
- 需要时间旅行查询（"这个订单在 3 天前是什么状态？"）
- 需要将状态投影为多种读模型（CQRS 的基础）
- 需要事件驱动的下游集成（通过事件自动通知其他系统）

### ❌ Wrong — 直接 Update 状态，丢失变更历史

```java
@Entity
@Table(name = "orders")
public class Order {
    @Id
    private Long id;
    private String status;
    private BigDecimal total;

    public void approve() {
        this.status = "APPROVED";
        // 谁批准的？什么时候？从什么状态变过来的？全部丢失。
    }

    public void cancel() {
        this.status = "CANCELLED";
        // 审计员问："这个订单为什么被取消？"——无法回答。
    }
}

@Transactional
public void approveOrder(Long orderId) {
    var order = orderRepo.findById(orderId).orElseThrow();
    order.approve();  // 原地覆盖，没有任何历史痕迹
    orderRepo.save(order);
}
```

**问题根源**：UPDATE 语句覆盖了之前的状态。数据库只保留了"现在是什么"，而丢失了"如何变成这样的"。这是不可逆的信息丢失。

### ✅ Expert Fix — Event Store + Snapshot + Replay

```java
// 事件存储表 — 只追加，永不修改
public record OrderEvent(
    Long eventId,
    Long orderId,
    String eventType,   // ORDER_CREATED, ORDER_APPROVED, ORDER_CANCELLED
    String payload,     // JSON serialized event body
    Long sequenceNumber,
    Instant occurredAt
) {}

// 快照表 — 定期生成，加速还原
public record OrderSnapshot(
    Long orderId,
    Long lastEventId,
    String state,       // 序列化的聚合当前状态
    Instant capturedAt
) {}

// 聚合根 — 状态由事件重建
public class Order {
    private OrderId id;
    private OrderStatus status;
    private Money total;
    private UserId approvedBy;
    private Instant approvedAt;
    private List<DomainEvent> uncommittedEvents = new ArrayList<>();
    private long version; // 乐观锁

    // 静态工厂：从事件历史重建当前状态
    public static Order fromEvents(List<OrderEvent> events) {
        var order = new Order();
        for (var event : events) {
            order.apply(event);
        }
        return order;
    }

    // 从快照 + 增量事件更高效地重建
    public static Order fromSnapshot(OrderSnapshot snapshot, List<OrderEvent> subsequentEvents) {
        var order = snapshot.toOrder(); // 恢复快照时的状态
        for (var event : subsequentEvents) { // 只重放快照之后的事件
            order.apply(event);
        }
        return order;
    }

    // 业务操作：产生事件，不直接修改状态
    public void approve(UserId approver, ApprovalPolicy policy) {
        if (!policy.canApprove(this)) {
            throw new CannotApproveException(id, status);
        }
        var event = new OrderApprovedEvent(id, approver, Instant.now());
        produceEvent(event);
    }

    public void cancel(UserId canceller, String reason) {
        if (status.isTerminal()) {
            throw new OrderAlreadyFinalException(id, status);
        }
        var event = new OrderCancelledEvent(id, canceller, reason, Instant.now());
        produceEvent(event);
    }

    private void produceEvent(DomainEvent event) {
        apply(event);  // 立即更新内存状态（保证一致性）
        uncommittedEvents.add(event);
    }

    // 事件分发器 — 根据事件类型调用对应的 apply 方法
    private void apply(DomainEvent event) {
        switch (event) {
            case OrderCreatedEvent e -> {
                this.id = e.orderId(); this.status = OrderStatus.DRAFT; this.total = e.total();
            }
            case OrderApprovedEvent e -> {
                this.status = OrderStatus.APPROVED; this.approvedBy = e.approvedBy(); this.approvedAt = e.occurredAt();
            }
            case OrderCancelledEvent e -> {
                this.status = OrderStatus.CANCELLED;
            }
            default -> throw new UnknownEventException(event);
        }
        this.version++;
    }

    public List<DomainEvent> getUncommittedEvents() { return List.copyOf(uncommittedEvents); }
    public void markEventsAsCommitted() { uncommittedEvents.clear(); }
}

// Repository — 追加事件，永不修改
@Repository
@RequiredArgsConstructor
public class OrderEventSourcedRepository {
    private final JdbcTemplate jdbc;
    private final ObjectMapper objectMapper;

    public void save(Order order) {
        var events = order.getUncommittedEvents();
        if (events.isEmpty()) return;

        // 乐观锁检查：version 必须匹配
        int updated = jdbc.update(
            "INSERT INTO order_events (order_id, event_type, payload, sequence_number, occurred_at) " +
            "SELECT ?, ?, ?::jsonb, ?, ? " +
            "WHERE NOT EXISTS (SELECT 1 FROM order_events WHERE order_id = ? AND sequence_number >= ?)",
            order.getId().value(), events.get(0).eventType(),
            toJson(events.get(0)), events.get(0).sequenceNumber(),
            events.get(0).occurredAt(),
            order.getId().value(), events.get(0).sequenceNumber()
        );
        if (updated == 0) {
            throw new OptimisticLockingException("Concurrent modification detected for order " + order.getId());
        }

        order.markEventsAsCommitted();

        // 每 50 个事件生成一次快照（异步）
        if (order.getVersion() % 50 == 0) {
            snapshotScheduler.schedule(order.getId());
        }
    }

    public Order findById(Long orderId) {
        // 优先从快照加载
        var snapshot = jdbc.queryForObject(
            "SELECT * FROM order_snapshots WHERE order_id = ? ORDER BY captured_at DESC LIMIT 1",
            snapshotRowMapper, orderId
        );

        List<OrderEvent> events;
        if (snapshot != null) {
            events = jdbc.query(
                "SELECT * FROM order_events WHERE order_id = ? AND sequence_number > ? ORDER BY sequence_number",
                eventRowMapper, orderId, snapshot.lastEventId()
            );
            return Order.fromSnapshot(snapshot, events);
        }

        // 没有快照，从全部事件重建
        events = jdbc.query(
            "SELECT * FROM order_events WHERE order_id = ? ORDER BY sequence_number",
            eventRowMapper, orderId
        );
        return Order.fromEvents(events);
    }
}
```

**Expert Note**：事件存储是「只追加」的——`INSERT` 但永不 `UPDATE` 或 `DELETE`。这带来了时间旅行能力，但也引入了性能代价：每次加载聚合需要重放事件。快照模式（每 N 个事件存一次全量快照）将还原复杂度从 O(n) 降到 O(1) + O(最近事件数)。生产环境中，快照的生成应异步进行，永不阻塞写入路径。

---

## ED-2: CQRS（命令查询职责分离）

**模式描述**：将「写操作」（Command）和「读操作」（Query）使用完全独立的模型处理。写模型面向业务不变量的强一致性；读模型面向展示需求，可做极致优化（去范式化、预聚合、缓存）。

**Use when**：
- 读与写的负载严重不对称（读写比 > 10:1）
- 查询涉及多聚合的 JOIN / 聚合，单纯靠 ORM 难以优化
- 读模型的数据形状与写模型差异巨大（例如订单列表页需要联表查用户、支付、物流）
- 需要独立的读写扩展策略（写侧纵向扩容，读侧横向分片）

### ❌ Wrong — 同一模型服务读写，读越权写

```java
@RestController
@RequestMapping("/orders")
@RequiredArgsConstructor
public class OrderController {
    private final OrderRepository orderRepo;

    // 写操作
    @PostMapping
    @Transactional
    public Order createOrder(@RequestBody CreateOrderRequest req) {
        var order = new Order(req.userId(), req.items());
        return orderRepo.save(order);
    }

    // 读操作 — 返回完整的 JPA Entity
    @GetMapping
    public List<Order> listOrders(@RequestParam String status) {
        return orderRepo.findByStatus(status);
        // 返回了所有字段：internalNotes, version, createdBy, lastModifiedBy...
        // 前端只需要 id, status, total, createdAt
        // N+1: 每个 Order 又懒加载了 items, payments, shipments
    }
}

// JPA Entity 兼任 DTO — 读模型 = 写模型 = 数据库表结构
@Entity
public class Order {
    @Id private Long id;
    private String status;
    private String internalNotes;    // 前端不应看到
    private Long version;            // 前端不应看到
    @OneToMany(mappedBy = "order", fetch = LAZY)
    private List<OrderItem> items;   // 序列化时触发 N+1
    @OneToMany(mappedBy = "order", fetch = LAZY)
    private List<Payment> payments;  // 序列化时触发 N+1
}
```

**问题根源**：一个模型承担两个完全不同的职责。写操作需要的是「业务规则 + 不变量的正确性」；读操作需要的是「给定查询条件下的最优数据形状」。用同一个模型服务两者，双方都得不到最优解。

### ✅ Expert Fix — Command 侧与 Query 侧独立演进

```java
// ==================== COMMAND SIDE（写模型） ====================

// 命令对象 — 意图明确的不可变 DTO
public record CreateOrderCommand(UserId userId, List<OrderLineItem> items) {}
public record ApproveOrderCommand(OrderId orderId, UserId approver) {}
public record CancelOrderCommand(OrderId orderId, UserId canceller, String reason) {}

// Command Handler — 每个命令一个处理器
@Component
@RequiredArgsConstructor
public class ApproveOrderCommandHandler {
    private final OrderWriteRepository orderRepo;
    private final ApprovalPolicy approvalPolicy;
    private final DomainEventPublisher eventPublisher;

    @Transactional
    public void handle(ApproveOrderCommand cmd) {
        var order = orderRepo.findById(cmd.orderId())
            .orElseThrow(() -> new OrderNotFoundException(cmd.orderId()));
        order.approve(cmd.approver(), approvalPolicy);
        orderRepo.save(order);
        eventPublisher.publish(order.getUncommittedEvents());
    }
}

// 写模型 — 面向业务不变量，不关心如何展示
public class Order {
    private OrderId id;
    private OrderStatus status;
    private List<OrderLine> lines;
    private Money total;
    private UserId approvedBy;
    private String internalMemo; // 内部备注，永远不暴露给前端

    public void addLine(ProductId product, int qty, Money price) {
        if (status != DRAFT) throw new OrderNotDraftException(id);
        if (qty <= 0) throw new InvalidQuantityException(qty);
        lines.add(new OrderLine(product, qty, price));
        recalculateTotal();
    }

    public void approve(UserId approver, ApprovalPolicy policy) {
        if (!policy.canApprove(this)) throw new CannotApproveException(id, status);
        this.status = APPROVED; this.approvedBy = approver;
    }
}

// ==================== QUERY SIDE（读模型） ====================

// 读模型 — 为每个查询场景量身定制
public record OrderListDto(
    Long id,
    String status,
    BigDecimal total,
    String currency,
    int itemCount,
    Instant createdAt
) {}

public record OrderDetailDto(
    Long id,
    String status,
    BigDecimal total,
    String currency,
    List<OrderItemDto> items,
    PaymentSummaryDto payment,
    String approverName,
    Instant approvedAt,
    Instant createdAt
) {}

// Query Handler — 直接查询读库（可以是独立的物化视图或只读副本）
@Component
@RequiredArgsConstructor
public class OrderQueryHandler {
    private final JdbcTemplate readJdbc; // 读库数据源

    public List<OrderListDto> listOrders(OrderStatus status, int page, int size) {
        // 直接 SQL 查询物化视图，一次 JOIN 返回全部数据
        return readJdbc.query("""
            SELECT o.id, o.status, o.total, o.currency,
                   o.item_count, o.created_at
            FROM order_read_model o
            WHERE o.status = ?
            ORDER BY o.created_at DESC
            LIMIT ? OFFSET ?
            """, orderListRowMapper, status.name(), size, page * size);
        // 单次查询，无 N+1，返回的数据 = 前端需要的 100%
    }

    public OrderDetailDto getOrderDetail(Long orderId) {
        // 读库中的详情表已经预先 JOIN 了所有关联数据
        return readJdbc.queryForObject("""
            SELECT o.*, p.status as payment_status, p.transaction_id,
                   u.name as approver_name
            FROM order_detail_view o
            LEFT JOIN payment_summary p ON o.id = p.order_id
            LEFT JOIN users u ON o.approved_by = u.id
            WHERE o.id = ?
            """, orderDetailRowMapper, orderId);
    }
}

// 读模型同步 — 监听领域事件，异步更新读库
@Component
@RequiredArgsConstructor
public class OrderReadModelProjector {
    private final JdbcTemplate readJdbc;

    @KafkaListener(topics = "order-events")
    public void on(ConsumerRecord<String, DomainEvent> record) {
        switch (record.value()) {
            case OrderCreatedEvent e -> readJdbc.update("""
                INSERT INTO order_read_model (id, status, total, currency, item_count, created_at)
                VALUES (?, ?, ?, ?, ?, ?)
                """, e.orderId().value(), "DRAFT", e.total().amount(), e.total().currency().code(),
                    e.lines().size(), e.occurredAt());

            case OrderApprovedEvent e -> readJdbc.update("""
                UPDATE order_read_model SET status = ?, approved_by = ?, approved_at = ?
                WHERE id = ?
                """, "APPROVED", e.approvedBy().value(), e.occurredAt(), e.orderId().value());

            case OrderCancelledEvent e -> readJdbc.update("""
                UPDATE order_read_model SET status = ? WHERE id = ?
                """, "CANCELLED", e.orderId().value());

            default -> { /* ignore other event types */ }
        }
    }
}
```

**Expert Note**：CQRS 的核心不是「读写分离数据库」，而是「读写模型分离思维」。Command Handler 关注的是：这个操作是否允许？业务不变量是否满足？Query Handler 关注的是：用户想看什么数据？用什么查询最快？两者解耦后，写模型可以走 Event Sourcing，读模型可以走 Elasticsearch——互不影响。唯一代价是「最终一致性」：读模型可能比写模型滞后几百毫秒。对于绝大多数业务场景，这个滞后完全可接受。

---

## ED-3: Message Ordering（消息顺序性）

**模式描述**：当事件之间存在因果关系时（如"创建订单"必须先于"支付订单"），必须保证同一实体的事件在消费端按生产顺序处理。Kafka 通过分区键（Partition Key）保证同一分区内的消息严格有序。

**Use when**：
- 事件之间有因果依赖（状态机流转：DRAFT → APPROVED → PAID → SHIPPED）
- 需要处理的增量更新（账户余额变更不能乱序）
- 聚合级别的强一致投影（CQRS 读模型的更新顺序必须与写操作一致）
- 使用 Kafka 且 topic 分区数 > 1

### ❌ Wrong — 随机分区导致乱序

```java
// Producer — 未指定分区键，消息随机散列到不同分区
@RequiredArgsConstructor
public class OrderEventPublisher {
    private final KafkaTemplate<String, OrderEvent> kafka;

    public void publish(OrderEvent event) {
        kafka.send("order-events", event);
        // 默认分区策略：没有 key → round-robin 到所有分区
        // order-123 的 CREATE 进了分区 2，APPROVE 进了分区 0
        // 消费者线程 1 处理分区 0 的 APPROVE（先到达）
        // 消费者线程 3 处理分区 2 的 CREATE（后到达）
        // → APPROVE 在 CREATE 之前被处理 → 状态机断裂
    }
}

// Consumer — 不检查幂等性，乱序消费直接写库
@Component
public class OrderProjector {
    @KafkaListener(topics = "order-events", concurrency = "3")
    public void project(OrderEvent event) {
        // 假设事件按序到达，直接应用
        if (event instanceof OrderApprovedEvent approved) {
            jdbc.update("UPDATE order_projection SET status = 'APPROVED' WHERE id = ?",
                approved.orderId());
            // 如果 CREATE 事件还没到，这条 UPDATE 找不到行，静默失败！
        }
    }
}
```

**问题根源**：Kafka 的 ordering guarantee 是 partition-level 的——同一分区内有序，跨分区无序。如果不指定 partition key，同一个 order 的事件可能去不同分区，消费端的并发处理必然导致乱序。

### ✅ Expert Fix — Partition Key + 单分区消费者 + 乐观版本号

```java
// Producer — 使用 orderId 作为分区键，同一订单的事件永远进同一分区
@RequiredArgsConstructor
public class OrderEventPublisher {
    private final KafkaTemplate<String, OrderEvent> kafka;

    public void publish(OrderEvent event) {
        var record = new ProducerRecord<>(
            "order-events",
            event.orderId().toString(), // KEY: 分区键 = 订单 ID
            event
        );
        // 添加自定义 header 用于幂等性校验
        record.headers().add("event-id", event.eventId().toString().getBytes(UTF_8));
        record.headers().add("sequence-number",
            String.valueOf(event.sequenceNumber()).getBytes(UTF_8));

        kafka.send(record);
        // 所有 order-123 的事件 → 同一分区 → 同一消费者线程 → 严格有序
    }
}

// Consumer — 单分区单线程消费 + 序列号顺序检查
@Component
public class OrderProjector {
    private final JdbcTemplate jdbc;

    @KafkaListener(
        topics = "order-events",
        concurrency = "1"  // 每个 partition 只分配一个 consumer thread
    )
    public void project(ConsumerRecord<String, OrderEvent> record) {
        var event = record.value();
        var seqNumber = Long.parseLong(
            new String(record.headers().lastHeader("sequence-number").value(), UTF_8));

        // 检查当前已处理的序列号：只处理序列号严格递增的事件
        Long lastSeq = jdbc.queryForObject(
            "SELECT last_sequence FROM order_event_offset WHERE order_id = ? FOR UPDATE",
            Long.class, event.orderId().value());

        if (lastSeq != null && seqNumber <= lastSeq) {
            log.info("Skipping duplicate or out-of-order event {} seq={}, last={}",
                event.eventId(), seqNumber, lastSeq);
            return; // 跳过乱序或重复的事件
        }

        if (lastSeq != null && seqNumber != lastSeq + 1) {
            // 序列号有缺口 — 说明有事件丢失，触发告警，暂停消费
            log.error("Gap detected for order {}: expected seq={}, got seq={}",
                event.orderId(), lastSeq + 1, seqNumber);
            metrics.eventGapDetected.increment();
            throw new EventGapException(event.orderId(), lastSeq + 1, seqNumber);
        }

        // 按序应用事件
        applyEvent(event);

        // 记录当前序列号
        jdbc.update(
            "INSERT INTO order_event_offset (order_id, last_sequence) VALUES (?, ?) " +
            "ON CONFLICT (order_id) DO UPDATE SET last_sequence = ?",
            event.orderId().value(), seqNumber, seqNumber);
    }

    private void applyEvent(OrderEvent event) {
        switch (event) {
            case OrderCreatedEvent e -> jdbc.update("""
                INSERT INTO order_projection (id, status, total, item_count, created_at)
                VALUES (?, 'DRAFT', ?, ?, ?)
                """, e.orderId().value(), e.total().amount(), e.lines().size(), e.occurredAt());

            case OrderApprovedEvent e -> jdbc.update("""
                UPDATE order_projection SET status = 'APPROVED', approved_by = ?, approved_at = ?
                WHERE id = ?
                """, e.approvedBy().value(), e.occurredAt(), e.orderId().value());

            case OrderCancelledEvent e -> jdbc.update("""
                UPDATE order_projection SET status = 'CANCELLED' WHERE id = ?
                """, e.orderId().value());

            default -> throw new UnknownEventTypeException(event.getClass());
        }
    }
}

// Kafka topic 的分区数 = 同一实体并发处理的理论上限
// 对 order 场景：200 个分区 = 最多 200 个订单的事件被并行消费
// 但同一订单的 CREATE → APPROVE → PAY → SHIP 严格串行
```

**Expert Note**：Kafka 的顺序保证需要三个条件同时成立：(1) Producer 指定一致的 partition key，(2) Topic 分区数不变（动态增加分区会 rehash，(3) Consumer 端单线程消费每个分区。序列号检查是额外的安全网——当以上任何一个条件被意外违反时，序列号缺口会被立即发现并告警，而不是静默产生错误数据。**永远不要依赖「消息一定有序」作为唯一保障，始终加序列号/版本号做防御性校验。**

---

## ED-4: Dead Letter Queue（死信队列）

**模式描述**：当消费者无法处理某条消息时（数据格式错误、业务规则校验失败、下游依赖不可用），将该消息转移到专门的 DLQ，避免阻塞主队列的后续消息处理。DLQ 中的消息可被人工审查、修复后重放，或自动重试。

**Use when**：
- 消息处理可能因消息内容而非系统故障而失败（poison message）
- 消息处理失败不应阻塞同一分区的后续消息（head-of-line blocking）
- 需要对失败消息做告警 + 人工介入 + 修复后重放
- 需要区分「可重试错误」（网络超时）和「不可重试错误」（格式错误）

### ❌ Wrong — 失败就无限重试，阻塞整个分区

```java
@Component
public class PaymentEventListener {
    private final PaymentGateway gateway;

    @KafkaListener(topics = "order-events")
    public void handle(ConsumerRecord<String, OrderEvent> record) {
        var event = record.value();

        try {
            gateway.capture(event.orderId(), event.total());
        } catch (Exception e) {
            // 错误 1：Spring Kafka 默认重试 10 次（可能还不够，也可能太多）
            // 错误 2：如果是 format error（如金额为负数），重试 100 次也没用
            // 错误 3：重试期间，同一分区的后续消息全部被阻塞（head-of-line blocking）
            log.error("Failed to process event: {}", event, e);
            throw e; // 抛出异常 → Kafka consumer 重新消费同一条消息 → 死循环
        }
    }
}
```

**问题根源**：Kafka consumer 对单个分区的消费是单线程串行的。当分区 N 的第 3 条消息处理失败并不断重试时，第 4、5、6……条消息永远得不到处理。这是「毒药消息阻塞整条管线」的经典场景。

### ✅ Expert Fix — 非阻塞重试 + DLQ + 告警

```java
// ==================== Kafka Consumer 配置 ====================

@Configuration
public class KafkaConsumerConfig {

    @Bean
    public ConcurrentKafkaListenerContainerFactory<String, OrderEvent> kafkaFactory(
            ConsumerFactory<String, OrderEvent> consumerFactory,
            KafkaTemplate<String, OrderEvent> kafkaTemplate) {

        var factory = new ConcurrentKafkaListenerContainerFactory<String, OrderEvent>();
        factory.setConsumerFactory(consumerFactory);

        // 关键配置 1：主消费不重试（抛异常 → 立即进 retry topic）
        var defaultErrorHandler = new DefaultErrorHandler(
            // 将失败消息发送到 retry topic，而非在主 topic 上原地重试
            new DeadLetterPublishingRecoverer(kafkaTemplate,
                (record, ex) -> {
                    // 根据异常类型决定目标 topic
                    return ex instanceof NonRetryableException
                        ? new TopicPartition("order-events-dlq", record.partition())
                        : new TopicPartition("order-events-retry", record.partition());
                }),
            // 主 topic 不做 backoff——立即转移，不阻塞
            new FixedBackOff(0L, 0L)
        );

        // 不再向主 topic 重试的消息类型
        defaultErrorHandler.addNotRetryableExceptions(
            InvalidEventFormatException.class,
            BusinessRuleViolationException.class,
            JsonMappingException.class
        );

        factory.setCommonErrorHandler(defaultErrorHandler);
        return factory;
    }

    // Retry topic 的消费者：指数退避重试
    @Bean
    public ConcurrentKafkaListenerContainerFactory<String, OrderEvent> retryFactory(
            ConsumerFactory<String, OrderEvent> consumerFactory,
            KafkaTemplate<String, OrderEvent> kafkaTemplate) {

        var factory = new ConcurrentKafkaListenerContainerFactory<String, OrderEvent>();
        factory.setConsumerFactory(consumerFactory);

        var retryErrorHandler = new DefaultErrorHandler(
            new DeadLetterPublishingRecoverer(kafkaTemplate,
                (record, ex) -> new TopicPartition("order-events-dlq", record.partition())),
            // Retry topic 使用指数退避：1s → 2s → 4s → 8s... → 最多 5 次
            new ExponentialBackOffWithMaxRetries(5)
        );
        // 指数退避后仍失败 → 进 DLQ
        retryErrorHandler.setBackOffFunction((record, ex, failedDeliveryAttempt) -> {
            long delay = (long) Math.min(
                Math.pow(2, failedDeliveryAttempt) * 1000L,
                30_000L  // 上限 30 秒
            );
            return delay;
        });

        factory.setCommonErrorHandler(retryErrorHandler);
        return factory;
    }
}

// ==================== 主事件消费者 ====================

@Component
public class PaymentEventListener {
    private final PaymentGateway gateway;
    private final RetryableFailureDetector failureDetector;

    @KafkaListener(
        topics = "order-events",
        containerFactory = "kafkaFactory"
    )
    public void handle(ConsumerRecord<String, OrderEvent> record) {
        var event = record.value();

        // 对可预期的业务规则失败主动抛 NonRetryableException
        if (event.total().isNegative()) {
            metrics.invalidEvent.increment();
            throw new NonRetryableException("Invalid negative total for order " + event.orderId());
        }

        try {
            // 下游临时不可用 → 抛 RetryableException → 进 retry topic
            gateway.capture(event.orderId(), event.total());
        } catch (GatewayTimeoutException e) {
            log.warn("Payment gateway timeout, will retry later: order={}", event.orderId());
            throw new RetryableException("Gateway timeout", e);
        }
    }
}

// ==================== DLQ 消费者 + 告警 ====================

@Component
public class DlqEventProcessor {
    private final JdbcTemplate jdbc;
    private final AlertService alert;

    @KafkaListener(topics = "order-events-dlq")
    public void processDlq(ConsumerRecord<String, OrderEvent> record) {
        var event = record.value();
        var lastHeader = record.headers().lastHeader("kafka_exceptionMessage");
        var errorMsg = lastHeader != null ? new String(lastHeader.value(), UTF_8) : "unknown";

        // DLQ 中的每条消息都需要被记录和告警
        DlqRecord dlqRecord = new DlqRecord(
            record.topic().replace("-dlq", ""), // 原始 topic
            record.partition(),
            record.offset(),
            event.eventId().toString(),
            event.getClass().getSimpleName(),
            errorMsg,
            toJson(event),
            Instant.now(),
            DlqStatus.PENDING_REVIEW
        );

        jdbc.update("""
            INSERT INTO dlq_records
            (original_topic, partition, offset_key, event_id, event_type,
             error_message, payload, arrived_at, status)
            VALUES (?, ?, ?, ?, ?, ?, ?::jsonb, ?, ?)
            """, dlqRecord.originalTopic(), dlqRecord.partition(),
            dlqRecord.offset(), dlqRecord.eventId(), dlqRecord.eventType(),
            dlqRecord.errorMessage(), dlqRecord.payload(),
            dlqRecord.arrivedAt(), dlqRecord.status().name());

        alert.send(Priority.HIGH,
            "DLQ received poison message: type=%s, topic=%s, error=%s"
                .formatted(event.getClass().getSimpleName(),
                    dlqRecord.originalTopic(), errorMsg.substring(0, 200)));
    }

    // 人工修复后重放的接口
    public void replay(Long dlqId) {
        var record = jdbc.queryForObject(
            "SELECT * FROM dlq_records WHERE id = ?", dlqRowMapper, dlqId);

        var event = fromJson(record.payload(), OrderEvent.class);
        kafka.send(record.originalTopic(), event.orderId().toString(), event);

        jdbc.update("UPDATE dlq_records SET status = ?, replayed_at = ? WHERE id = ?",
            DlqStatus.REPLAYED.name(), Instant.now(), dlqId);
    }
}
```

**Expert Note**：DLQ 设计有两个关键决策：(1) **retry topic 的存在**——不要在原始 topic 上原地重试。将失败消息快速转移到 retry topic，释放主 topic 的消费能力。retry topic 可以用较慢的指数退避策略慢慢试；(2) **分清 Retryable 和 NonRetryable**——格式错误重试一万次也没用，应立刻进 DLQ；网络超时则是暂时的，值得重试 N 次。**DLQ 不是垃圾箱，是待处理队列**——每条进 DLQ 的消息都必须产生告警，有 Owner，有 SLA（例如 2 小时内必须审查）。

---

## ED-5: Exactly-Once vs At-Least-Once（精确一次 vs 至少一次）

**模式描述**：在分布式消息系统中，「精确一次」语义依赖生产者和消费者的协同。Kafka 通过幂等生产者（Idempotent Producer）和事务 API 支持 exactly-once；跨系统的精确一次则需要 Transactional Outbox 模式——将业务数据写入和事件发布放在同一个数据库事务中，通过 CDC（Change Data Capture）异步发布。

**Use when**：
- 支付、扣库存等绝对不能重复执行的操作
- Producer 侧需要保证 "业务写入 + 事件发布" 的原子性
- 无法承受重复消息带来的业务影响（双重扣费、重复发货）
- 跨数据库和消息队列的原子写入（Outbox Pattern 的核心场景）

### ❌ Wrong — 数据库写入和消息发送分离，双重写入问题

```java
// 经典的双重写入问题（Dual Write Problem）
@Transactional
public void approveOrder(Long orderId) {
    // Step 1: 数据库写入成功
    var order = orderRepo.findById(orderId).orElseThrow();
    order.setStatus(OrderStatus.APPROVED);
    orderRepo.save(order);

    // Step 2: 发送 Kafka 消息
    try {
        kafka.send("order-events",
            new OrderApprovedEvent(orderId, currentUser(), Instant.now()));
        // 如果这里成功 → 完美
    } catch (Exception e) {
        // 消息发送失败，但数据库已经 COMMIT 了！
        // 数据库有 APPROVED 状态，但没有任何消费者知道这件事
        // → 下游系统（支付、通知、物流）永远收不到这个事件
        log.error("Failed to publish event for order {}", orderId, e);
        // 是不是应该回滚数据库？不行——@Transactional 已经提交了
    }
}

// 另一种错误：先发消息再写数据库
public void approveOrder(Long orderId) {
    // Step 1: 先发消息
    kafka.send("order-events", new OrderApprovedEvent(orderId));

    // Step 2: 写数据库
    orderRepo.updateStatus(orderId, APPROVED);
    // 如果 Step 2 失败——消息已发出，消费者认为订单已批准；数据库里没有
    // → 消费者处理消息时订单还不存在 → 错误
}
```

**问题根源**：数据库和 Kafka 是两个独立的系统，没有共享的事务上下文。任何 "先 A 后 B" 的尝试都会面临「A 成功 B 失败」导致的不一致状态。这是分布式系统中最根本的挑战之一。

### ✅ Expert Fix — Transactional Outbox Pattern（事务发件箱）

```java
// ==================== Outbox 表结构 ====================
/*
CREATE TABLE outbox_events (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    aggregate_type  VARCHAR(255) NOT NULL,
    aggregate_id    VARCHAR(255) NOT NULL,
    event_type      VARCHAR(255) NOT NULL,
    payload         JSONB NOT NULL,
    created_at      TIMESTAMP NOT NULL DEFAULT NOW(),
    published_at    TIMESTAMP,
    status          VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    retry_count     INT NOT NULL DEFAULT 0,
    INDEX idx_status_created (status, created_at)
);
*/

// ==================== 业务写入 + Outbox 写入在同一事务 ====================

@Entity
@Table(name = "outbox_events")
public class OutboxEvent {
    @Id
    private UUID id;
    private String aggregateType;
    private String aggregateId;
    private String eventType;
    @Column(columnDefinition = "jsonb")
    private String payload;
    private Instant createdAt;
    private Instant publishedAt;
    private OutboxStatus status;
    private int retryCount;

    public static OutboxEvent from(DomainEvent event) {
        return new OutboxEvent(
            UUID.randomUUID(),
            event.aggregateType(),
            event.aggregateId(),
            event.eventType(),
            toJson(event),
            Instant.now(),
            null,
            OutboxStatus.PENDING,
            0
        );
    }
}

@Service
@RequiredArgsConstructor
public class OrderApplicationService {
    private final OrderRepository orderRepo;
    private final OutboxEventRepository outboxRepo;

    @Transactional  // 单数据库事务，同时覆盖 order 和 outbox
    public void approveOrder(OrderId orderId, UserId approver) {
        var order = orderRepo.findById(orderId)
            .orElseThrow(() -> new OrderNotFoundException(orderId));

        var event = order.approve(approver); // 聚合返回领域事件
        orderRepo.save(order);

        // 将事件写入 outbox 表 —— 与 order 在同一个 DB 事务中
        outboxRepo.save(OutboxEvent.from(event));

        // 事务提交：order 状态更新 AND outbox 事件同时生效
        // 如果任何一步失败，整个事务回滚 —— 原子性保证
        // 事务提交后，CDC 组件（下面）会将事件从 outbox 发布到 Kafka
    }
}

// ==================== Debezium CDC 连接器自动发布 Outbox 事件 ====================

// Debezium 配置（connector JSON）：
/*
{
  "name": "outbox-connector",
  "config": {
    "connector.class": "io.debezium.connector.postgresql.PostgresConnector",
    "plugin.name": "pgoutput",
    "database.hostname": "orders-db",
    "database.port": "5432",
    "database.user": "debezium",
    "database.password": "...",
    "database.dbname": "orders",
    "table.include.list": "public.outbox_events",
    "publication.autocreate.mode": "filtered",

    "transforms": "outbox",
    "transforms.outbox.type": "io.debezium.transforms.outbox.EventRouter",
    "transforms.outbox.route.topic.replacement": "${routedByValue}",
    "transforms.outbox.table.field.event.id": "id",
    "transforms.outbox.table.field.event.key": "aggregate_id",
    "transforms.outbox.table.field.event.payload": "payload",
    "transforms.outbox.route.by.field": "event_type",
    "transforms.outbox.table.expand.json.payload": "true"
  }
}
*/
// Debezium 自动：
// 1. 监控 PostgreSQL WAL，发现 outbox_events 表有新行
// 2. EventRouter SMT 将行转换为 Kafka 消息
// 3. 发布到 topic（topic 名 = event_type 字段的值，如 "OrderApproved"）
// 4. 发布成功后标记 published_at

// ==================== 消息发布重试（应对 CDC 短暂故障） ====================

@Component
public class OutboxPoller {
    private final OutboxEventRepository outboxRepo;
    private final KafkaTemplate<String, String> kafka;

    @Scheduled(fixedDelay = 5000) // 每 5 秒兜底轮询一次
    public void publishPendingEvents() {
        var pending = outboxRepo.findByStatusAndCreatedAtBefore(
            OutboxStatus.PENDING, Instant.now().minusSeconds(30), PageRequest.of(0, 100));

        for (var event : pending) {
            try {
                kafka.send(event.getEventType(), event.getAggregateId(),
                    event.getPayload()).get(5, SECONDS);

                event.markPublished();
                outboxRepo.save(event);
            } catch (Exception e) {
                log.warn("Outbox publish retry failed: eventId={}, attempt={}",
                    event.getId(), event.getRetryCount() + 1, e);

                event.incrementRetry();
                if (event.getRetryCount() >= 10) {
                    event.markFailed();
                    alert.send(Priority.CRITICAL,
                        "Outbox event {} failed after 10 retries", event.getId());
                }
                outboxRepo.save(event);
            }
        }
    }
}

// ==================== 幂等生产者（Kafka Exactly-Once） ====================

// 对于无法使用 Outbox 的场景，Kafka 自身提供 exactly-once 语义：
@Configuration
public class ExactlyOnceProducerConfig {

    @Bean
    public ProducerFactory<String, OrderEvent> producerFactory() {
        var config = new HashMap<String, Object>();
        config.put(BOOTSTRAP_SERVERS_CONFIG, "kafka:9092");

        // 启用幂等生产者：自动去重 broker 端的重复消息
        config.put(ENABLE_IDEMPOTENCE_CONFIG, true);

        // 启用事务：多个 partition 的写入原子化
        config.put(TRANSACTIONAL_ID_CONFIG, "order-service-tx-" + instanceId);

        // 消息确认设为 "all" —— 所有 ISR 副本确认后才算成功
        config.put(ACKS_CONFIG, "all");

        // 限制每个连接的最大未确认请求数（幂等性的前提）
        config.put(MAX_IN_FLIGHT_REQUESTS_PER_CONNECTION, 5);

        return new DefaultKafkaProducerFactory<>(config);
    }

    @Bean
    public KafkaTransactionManager<String, OrderEvent> transactionManager(
            ProducerFactory<String, OrderEvent> producerFactory) {
        return new KafkaTransactionManager<>(producerFactory);
    }
}

// 使用 Kafka 事务 + 数据库事务（Chained Transaction）
@Service
@RequiredArgsConstructor
public class OrderServiceWithKafkaTx {
    private final OrderRepository orderRepo;
    private final KafkaTemplate<String, OrderEvent> kafka;

    @Transactional("chainedTransactionManager") // DB + Kafka 链式事务
    public void approveOrder(OrderId orderId, UserId approver) {
        var order = orderRepo.findById(orderId).orElseThrow();
        var event = order.approve(approver);
        orderRepo.save(order);

        // Kafka 消息发送在当前事务的上下文中：
        //   1. DB 事务先提交
        //   2. 如果 DB 提交成功 → Kafka 事务提交（消息发布）
        //   3. 如果 Kafka 提交失败 → 消息丢失（不如 Outbox 模式可靠）
        kafka.send("order-events", orderId.toString(), event);

        // 注意：这种链式事务仍有可能出现 "DB committed + Kafka NOT committed"
        // 对于绝对不容许丢失的场景，Outbox Pattern 仍然是唯一选择
    }
}
```

**Expert Note**：「Exactly-Once」是一个需要祛魅的术语。Kafka 的 exactly-once 严格来说只是「exactly-once in the Kafka stream」——生产者不重复写入、消费者不重复读取。但一旦消费者需要将数据写入外部系统（数据库、API），exactly-once 的语义就断裂了。**Transactional Outbox Pattern 是唯一能在跨系统场景下保证 at-least-once 且不丢消息的方案**：把"业务写入"和"事件标记"放在同一个数据库事务里，让数据库保证原子性，然后用 CDC 异步发布。代价是事件发布的延迟（取决于 CDC 的 WAL 轮询间隔，通常 < 1s），换来的是绝对不丢事件的保证。这是一个典型的 tradeoff：延迟 vs 可靠性。对于支付场景，选可靠性。

---

## 快速审查清单

在审查事件驱动架构设计时，请检查以下信号：

- [ ] 状态变更是否只有 UPDATE，没有历史记录？→ **需要 Event Sourcing（ED-1）**
- [ ] 一个 Model/DTO 同时服务于读写两端？→ **需要 CQRS（ED-2）**
- [ ] 聚合的读写比 > 10:1，但还在用同一张表？→ **需要 CQRS（ED-2）**
- [ ] Producer 发送消息未指定 partition key？→ **消息乱序风险（ED-3）**
- [ ] Consumer 静默吞掉处理失败的异常？→ **Poison message 无感知（ED-4）**
- [ ] 失败消息的主 topic 原地重试？→ **Head-of-line blocking（ED-4）**
- [ ] 数据库写入和消息发送在两个独立步骤中？→ **双重写入问题（ED-5）**
- [ ] 没有 Outbox 表或 CDC 机制？→ **事件丢失风险（ED-5）**
- [ ] 业务结果依赖消息精确不重复？→ **必须用 Outbox 或幂等消费者（ED-5）**
- [ ] DLQ 没有告警和人工处理流程？→ **死信消息被遗忘（ED-4）**
