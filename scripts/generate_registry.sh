#!/bin/bash
# Bash script to generate registry.yaml and registry.lst

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
SKILLS_DIR="$REPO_ROOT/skills"

parse_frontmatter() {
    local skill_path="$1"
    if [ ! -f "$skill_path" ]; then
        return 1
    fi
    
    content=$(cat "$skill_path")
    if ! echo "$content" | grep -q '^---'; then
        return 1
    fi
    
    frontmatter=$(echo "$content" | sed -n '/^---$/,/^---$/p' | sed '1d;$d')
    
    name=$(echo "$frontmatter" | grep '^name:' | sed 's/^name:\s*//')
    display_name=$(echo "$frontmatter" | grep '^displayName:' | sed 's/^displayName:\s*//')
    version=$(echo "$frontmatter" | grep '^version:' | sed 's/^version:\s*//')
    domain=$(echo "$frontmatter" | grep '^domain:' | sed 's/^domain:\s*//')
    tags=$(echo "$frontmatter" | grep '^tags:' | sed 's/^tags:\s*\[//;s/\]//;s/^["'\'']//;s/["'\'']$//;s/["'\''],\s*/,/g;s/,\s*["'\'']/,/g')
    
    [ -z "$name" ] && name="$skill_dir_name"
    [ -z "$display_name" ] && display_name="$name"
    [ -z "$version" ] && version="1.0.0"
    [ -z "$domain" ] && domain=""
    
    echo "$name|$display_name|$version|$domain|$tags"
}

generate_registry() {
    cd "$REPO_ROOT" || exit 1
    
    if [ ! -d "$SKILLS_DIR" ]; then
        echo "Directory $SKILLS_DIR not found"
        exit 1
    fi
    
    current_date=$(date +%Y-%m-%d)
    skills_list=()
    yaml_skills=""
    
    for skill_dir in "$SKILLS_DIR"/*/; do
        skill_dir_name=$(basename "$skill_dir")
        skill_md="$skill_dir/SKILL.md"
        
        if [ ! -f "$skill_md" ]; then
            continue
        fi
        
        skill_rel_path=$(echo "$skill_dir" | sed "s|^$REPO_ROOT/||;s|/$||")
        frontmatter_data=$(parse_frontmatter "$skill_md")
        
        if [ -z "$frontmatter_data" ]; then
            continue
        fi
        
        IFS='|' read -r name display_name version domain tags <<< "$frontmatter_data"
        skills_list+=("$name|$skill_rel_path|$version|$display_name|$domain|$tags")
        
        yaml_skills+="
  - name: $name
    path: $skill_rel_path
    version: $version
    title: $display_name
    domain: $domain
    tags: [$tags]
"
    done
    
    cat > "$REPO_ROOT/registry.yaml" << EOF
version: "1.0"
updated: "$current_date"
skills:
$yaml_skills
EOF
    
    lst_content=""
    for skill in "${skills_list[@]}"; do
        lst_content+="$skill"$'\n'
    done
    
    echo -n "$lst_content" > "$REPO_ROOT/registry.lst"
    
    skill_count=${#skills_list[@]}
    echo "Generated registry.yaml with $skill_count skills"
    echo "Generated registry.lst with $skill_count skills"
}

generate_registry
