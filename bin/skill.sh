#!/bin/bash
# Skill-Hub CLI - Bash 版本
# 把 Confluence 的理论知识，变成 AI 帮你干活的能力

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
SKILLS_DIR="$REPO_ROOT/skills"
REGISTRY_LST_PATH="$REPO_ROOT/registry.lst"
LOCAL_SKILLHUB_DIR="$HOME/.skillhub"
LOCAL_SKILLS_DIR="$LOCAL_SKILLHUB_DIR/skills"

show_help() {
    echo "Skill-Hub CLI - 把 Confluence 的理论知识，变成 AI 帮你干活的能力"
    echo ""
    echo "Usage: skill command [args]"
    echo ""
    echo "Commands:"
    echo "  search keyword   - 搜索 Skill"
    echo "  install name    - 安装 Skill 到本地"
    echo "  uninstall name  - 卸载本地 Skill"
    echo "  run name        - 执行 Skill"
    echo "  list            - 列出所有 Skill"
    echo "  help            - 显示帮助"
    echo ""
}

load_registry() {
    if [ ! -f "$REGISTRY_LST_PATH" ]; then
        echo "Error: registry.lst not found at $REGISTRY_LST_PATH" >&2
        if [ -f "$REPO_ROOT/scripts/generate_registry.sh" ]; then
            echo "Please run: scripts/generate_registry.sh (or scripts/generate_registry.ps1 on Windows)" >&2
        else
            echo "Warning: generate_registry.sh script not found" >&2
        fi
        exit 1
    fi
    
    skills=()
    line_number=0
    
    while IFS= read -r line; do
        line_number=$((line_number + 1))
        line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        
        if [ -z "$line" ]; then
            continue
        fi
        
        IFS='|' read -r name path version title domain tags <<< "$line"
        
        name=$(echo "$name" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        path=$(echo "$path" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        version=$(echo "$version" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        title=$(echo "$title" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        domain=$(echo "$domain" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        tags=$(echo "$tags" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        
        if [ -z "$name" ] || [ -z "$path" ]; then
            echo "Warning: Invalid entry at line $line_number has empty name or path, skipping" >&2
            continue
        fi
        
        if [ -z "$title" ]; then
            title="$name"
        fi
        
        if [ -z "$version" ]; then
            version=""
        fi
        
        if [ -z "$domain" ]; then
            domain=""
        fi
        
        if [ -z "$tags" ]; then
            tags=""
        fi
        
        skills+=("$name|$path|$version|$title|$domain|$tags")
    done < "$REGISTRY_LST_PATH"
    
    if [ ${#skills[@]} -eq 0 ]; then
        echo "Warning: No valid skills found in registry.lst" >&2
    fi
}

search_skill() {
    keyword="$1"
    load_registry
    
    results=()
    for skill in "${skills[@]}"; do
        IFS='|' read -r name path version title domain tags <<< "$skill"
        match=0
        if [ -z "$keyword" ]; then
            match=1
        else
            kw_lower=$(echo "$keyword" | tr '[:upper:]' '[:lower:]')
            name_lower=$(echo "$name" | tr '[:upper:]' '[:lower:]')
            title_lower=$(echo "$title" | tr '[:upper:]' '[:lower:]')
            tags_lower=$(echo "$tags" | tr '[:upper:]' '[:lower:]')
            if [[ "$name_lower" == *"$kw_lower"* ]] || [[ "$title_lower" == *"$kw_lower"* ]] || [[ "$tags_lower" == *"$kw_lower"* ]]; then
                match=1
            fi
        fi
        if [ $match -eq 1 ]; then
            results+=("$skill")
        fi
    done
    
    if [ ${#results[@]} -eq 0 ]; then
        echo "No skills found"
        return
    fi
    
    echo ""
    printf "%-30s %-40s %-10s %-10s\n" "NAME" "TITLE" "DOMAIN" "VERSION"
    printf "%-95s\n" "-----------------------------------------------------------------------------------------------"
    for skill in "${results[@]}"; do
        IFS='|' read -r name path version title domain tags <<< "$skill"
        printf "%-30s %-40s %-10s %-10s\n" "$name" "$title" "$domain" "$version"
    done
    echo ""
    echo "Found ${#results[@]} skill(s)"
}

install_skill() {
    name="$1"
    load_registry
    
    found=0
    skill_path=""
    for skill in "${skills[@]}"; do
        IFS='|' read -r s_name s_path s_version s_title s_domain s_tags <<< "$skill"
        if [ "$s_name" = "$name" ]; then
            found=1
            skill_path="$s_path"
            break
        fi
    done
    
    if [ $found -eq 0 ]; then
        echo "Skill '$name' not found" >&2
        exit 1
    fi
    
    mkdir -p "$LOCAL_SKILLS_DIR"
    
    dest_dir="$LOCAL_SKILLS_DIR/$name"
    src_skill_md="$REPO_ROOT/$skill_path/SKILL.md"
    dest_skill_md="$dest_dir/SKILL.md"
    
    if [ ! -f "$src_skill_md" ]; then
        echo "Error: SKILL.md not found at $src_skill_md" >&2
        exit 1
    fi
    
    if [ -d "$dest_dir" ]; then
        echo "Skill '$name' is already installed at $dest_dir"
        read -p "Overwrite? (y/N) " overwrite
        if [ "$overwrite" != "y" ] && [ "$overwrite" != "Y" ]; then
            echo "Installation cancelled"
            return
        fi
        rm -rf "$dest_dir"
    fi
    
    mkdir -p "$dest_dir"
    cp "$src_skill_md" "$dest_skill_md"
    
    echo "Skill '$name' installed successfully to $dest_dir"
}

uninstall_skill() {
    name="$1"
    dest_dir="$LOCAL_SKILLS_DIR/$name"
    
    if [ ! -d "$dest_dir" ]; then
        echo "Skill '$name' is not installed" >&2
        exit 1
    fi
    
    rm -rf "$dest_dir"
    echo "Skill '$name' uninstalled successfully"
}

list_skills() {
    search_skill ""
}

run_skill() {
    name="$1"
    dest_dir="$LOCAL_SKILLS_DIR/$name"
    skill_md="$dest_dir/SKILL.md"
    
    if [ ! -d "$dest_dir" ]; then
        echo "Skill '$name' is not installed at $dest_dir" >&2
        echo "Please install it first: skill install $name" >&2
        exit 1
    fi
    
    if [ ! -f "$skill_md" ]; then
        echo "Error: SKILL.md not found at $skill_md" >&2
        exit 1
    fi
    
    echo "=== Skill: $name ==="
    echo ""
    cat "$skill_md"
}

case "$1" in
    search)
        search_skill "$2"
        ;;
    install)
        install_skill "$2"
        ;;
    uninstall)
        uninstall_skill "$2"
        ;;
    run)
        run_skill "$2"
        ;;
    list)
        list_skills
        ;;
    help)
        show_help
        ;;
    *)
        show_help
        ;;
esac
