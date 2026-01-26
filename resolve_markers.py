#!/usr/bin/env python3
"""
Post-process markdown files to resolve marker-based includes to line numbers.

This script finds include directives with marker names:
    <!--@include: path{#start-marker,#end-marker}-->

And resolves them to actual line numbers:
    <!--@include: path{35,340}-->

By searching for HTML comment markers in the target file:
    <!-- start-marker -->
    <!-- end-marker -->
"""

import os
import re
import sys

def find_marker_line_in_markdown(file_path, marker_name):
    """Find the line number of an HTML comment marker in a markdown file."""
    if not os.path.exists(file_path):
        return None
    
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            lines = f.readlines()
        
        for line_num, line in enumerate(lines, start=1):
            # Look for HTML comment markers
            if f'<!-- {marker_name} -->' in line:
                return line_num
        
    except Exception as e:
        sys.stderr.write(f"Error reading {file_path}: {e}\n")
    
    return None

def resolve_include_markers(content, base_dir):
    """
    Resolve marker-based includes to line numbers.
    
    Finds patterns like: <!--@include: path{#start,#end}-->
    Resolves to: <!--@include: path{10,50}-->
    """
    # Pattern to match include directives with marker references
    pattern = r'(<!--@include:\s*)([^{]+)(\{#([^,}]+),#([^}]+)\})(-->)'
    
    def replace_markers(match):
        prefix = match.group(1)
        include_path = match.group(2).strip()
        markers_part = match.group(3)
        start_marker = match.group(4)
        end_marker = match.group(5)
        suffix = match.group(6)
        
        # Resolve the include path relative to base_dir
        target_file = os.path.join(base_dir, include_path)
        target_file = os.path.normpath(target_file)
        
        # Find the markers in the target file
        start_line = find_marker_line_in_markdown(target_file, start_marker)
        end_line = find_marker_line_in_markdown(target_file, end_marker)
        
        if start_line is None or end_line is None:
            sys.stderr.write(f"Warning: Could not find markers '{start_marker}' and/or '{end_marker}' in {target_file}\n")
            sys.stderr.write(f"  start_line: {start_line}, end_line: {end_line}\n")
            # Keep the original marker-based syntax
            return match.group(0)
        
        # Content should be between the markers
        # Start after the start marker, end before the end marker
        actual_start = start_line + 1
        actual_end = end_line - 1
        
        if actual_start >= actual_end:
            sys.stderr.write(f"Warning: Invalid marker range in {target_file}: {start_marker}({start_line}) to {end_marker}({end_line})\n")
            return match.group(0)
        
        # Return the resolved include directive
        return f'{prefix}{include_path}{{{actual_start},{actual_end}}}{suffix}'
    
    # Replace all marker-based includes
    resolved = re.sub(pattern, replace_markers, content)
    return resolved

def process_file(file_path, output_root):
    """Process a single markdown file to resolve include markers."""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Check if file contains marker-based includes
        if '<!--@include:' not in content or '{#' not in content:
            return False
        
        # Get the directory of the current file for relative path resolution
        file_dir = os.path.dirname(file_path)
        
        resolved_content = resolve_include_markers(content, file_dir)
        
        if resolved_content != content:
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(resolved_content)
            return True
        
    except Exception as e:
        sys.stderr.write(f"Error processing {file_path}: {e}\n")
    
    return False

def main():
    if len(sys.argv) < 2:
        print("Usage: resolve_markers.py <output_directory>")
        print("  Processes all .md files in the output directory to resolve marker-based includes")
        sys.exit(1)
    
    output_dir = sys.argv[1]
    
    if not os.path.isdir(output_dir):
        sys.stderr.write(f"Error: {output_dir} is not a directory\n")
        sys.exit(1)
    
    # Find all markdown files
    processed_count = 0
    for root, dirs, files in os.walk(output_dir):
        for file in files:
            if file.endswith('.md'):
                file_path = os.path.join(root, file)
                if process_file(file_path, output_dir):
                    processed_count += 1
                    print(f"Resolved markers in: {file_path}")
    
    print(f"\nProcessed {processed_count} files with marker-based includes")

if __name__ == '__main__':
    main()
