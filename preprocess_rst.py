#!/usr/bin/env python3
import re
import sys
import os

def find_marker_line_numbers(include_path, start_marker, end_marker):
    """Try to find the actual line numbers for the markers in the target file."""
    base_path = os.getenv('SOURCE_FOLDER', '')
    if not base_path:
        sys.stderr.write(f"WARNING: SOURCE_FOLDER not set for {include_path}\\n")
        return None
    
    # Determine if include_path is relative (./...) or absolute (/...)
    if include_path.startswith('./') or include_path.startswith('../'):
        # Relative path - resolve from current file's directory
        current_file = os.getenv('CURRENT_RST_FILE', '')
        if current_file:
            current_dir = os.path.dirname(os.path.join(base_path, current_file))
        else:
            current_dir = base_path
        file_path = os.path.normpath(os.path.join(current_dir, include_path))
    else:
        # Absolute path (relative to doc root) - find the doc root
        # SOURCE_FOLDER might be a subdirectory like legacy/en/views/helpers
        # We need to find the doc root by going up to where 'legacy' or the language folder is
        # e.g., /path/to/legacy/en/views/helpers -> /path/to/legacy/en
        parts = base_path.split(os.sep)
        # Find 'en', 'ja', 'es', etc. and use up to that as the base
        lang_idx = -1
        for i, part in enumerate(parts):
            if part in ['en', 'ja', 'es', 'fr', 'pt', 'de']:
                lang_idx = i
                break
        
        if lang_idx >= 0:
            doc_root = os.sep.join(parts[:lang_idx+1])
        else:
            doc_root = base_path
        
        # Try RST file in documentation root
        file_path = os.path.join(doc_root, include_path)
    
    if not os.path.exists(file_path):
        return None
    
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            file_lines = f.readlines()
        
        start_line = None
        end_line = None
        
        for line_num, file_line in enumerate(file_lines, start=1):
            # Look for RST comment markers
            if start_marker and not start_line:
                if f'.. {start_marker}' in file_line:
                    start_line = line_num + 1  # Include content after marker
            
            if end_marker and not end_line:
                if f'.. {end_marker}' in file_line:
                    end_line = line_num - 1  # Include content before marker
        
        # If we found both markers, return the range
        if start_line and end_line and start_line < end_line:
            return (start_line, end_line)
        # If we only found start, include to end of file
        elif start_line:
            return (start_line, len(file_lines))
        # If we only found end, include from beginning
        elif end_line:
            return (1, end_line)
            
    except Exception:
        pass
    
    return None

def convert_include_to_vitepress(content, current_file):
    """Convert RST include directives to VitePress markdown file inclusion syntax."""
    lines = content.split('\n')
    result_lines = []
    i = 0
    
    while i < len(lines):
        line = lines[i]
        
        # Check if this is an include directive
        include_match = re.match(r'^(\s*)\.\. include::\s*(.+)', line)
        if include_match:
            indent = include_match.group(1)
            include_path = include_match.group(2).strip()
            
            # Determine if this is an absolute path (starts with /) or relative path (starts with ./)
            is_absolute = include_path.startswith('/')
            
            # Remove leading slash for absolute paths (RST uses absolute paths from docs root)
            if is_absolute:
                include_path = include_path.lstrip('/')
            
            # Change .rst to .md for the output path
            include_path_md = re.sub(r'\.rst$', '.md', include_path)
            
            # Calculate relative path from current file
            current_dir = os.path.dirname(current_file) if current_file else ''
            
            # Calculate relative path
            if is_absolute:
                # For absolute includes, we need to go up from current file to doc root, then down to target
                if current_dir:
                    # Count directory depth
                    depth = len([p for p in current_dir.split('/') if p])
                    # Build relative path
                    relative_path = '../' * depth + include_path_md
                else:
                    relative_path = include_path_md
            else:
                # For relative includes, path is already relative to current file
                relative_path = include_path_md
            
            # Collect any options (:start-after:, :end-before:)
            options = {}
            i += 1
            while i < len(lines):
                option_line = lines[i]
                # Check if this is an option line (starts with :)
                option_match = re.match(r'^\s+:([^:]+):\s*(.+)', option_line)
                if option_match:
                    option_name = option_match.group(1).strip()
                    option_value = option_match.group(2).strip()
                    options[option_name] = option_value
                    i += 1
                elif not option_line.strip():
                    # Empty line, continue
                    i += 1
                else:
                    # Not an option line, stop collecting options
                    break
            
            # Try to find line numbers if we have start-after/end-before markers
            # Changed: Output marker names instead of line numbers for post-processing
            
            # Generate VitePress include syntax as RST raw HTML directive
            result_lines.append('')
            result_lines.append(f'{indent}.. raw:: html')
            result_lines.append('')
            
            if 'start-after' in options or 'end-before' in options:
                start_marker = options.get('start-after', '')
                end_marker = options.get('end-before', '')
                result_lines.append(f'{indent}   <!--@include: {relative_path}{{#{start_marker},#{end_marker}}}-->')
            else:
                result_lines.append(f'{indent}   <!--@include: {relative_path}-->')
                
                # Add comment about options if they exist
                if options:
                    option_comments = []
                    for key, value in options.items():
                        option_comments.append(f'{key}: {value}')
                    result_lines.append(f'{indent}   <!-- Include options: {", ".join(option_comments)} -->')
            
            result_lines.append('')
            
            # i is already advanced by the while loop
            continue
        
        result_lines.append(line)
        i += 1
    
    return '\n'.join(result_lines)

def fix_literal_blocks_in_directives(content):
    """
    Convert literal blocks (::) inside directives (note, warning, etc.) 
    into explicit code-block directives so Pandoc preserves them as code.
    """
    lines = content.split('\n')
    result = []
    i = 0
    
    while i < len(lines):
        line = lines[i]
        
        # Check if this is a directive (note, warning, tip, etc.)
        directive_match = re.match(r'^(\s*)\.\.\s+(note|warning|tip|important|caution|danger|attention|hint|seealso|admonition)::\s*(.*)$', line)
        
        if directive_match:
            indent = directive_match.group(1)
            directive_type = directive_match.group(2)
            directive_args = directive_match.group(3)
            
            # Add the directive line
            result.append(line)
            i += 1
            
            # Expected content indentation (directive indent + 4 spaces)
            content_indent = indent + '    '
            
            # Process the content of the directive
            while i < len(lines):
                current_line = lines[i]
                
                # Check if we've left the directive (dedented or empty line at directive level)
                if current_line.strip() and not current_line.startswith(content_indent):
                    # We've left the directive
                    break
                
                # Check if this line ends with :: (literal block marker)
                if current_line.rstrip().endswith('::') and current_line.strip() != '::':
                    # This is a literal block marker
                    # Remove the :: and add it as regular text
                    result.append(current_line[:-1])  # Remove the trailing :
                    i += 1
                    
                    # Skip any blank lines
                    while i < len(lines) and not lines[i].strip():
                        result.append(lines[i])
                        i += 1
                    
                    # Now we should have the code block
                    # Expected code indent is content_indent + 4 more spaces
                    code_indent = content_indent + '    '
                    
                    if i < len(lines) and lines[i].startswith(code_indent):
                        # We have a code block - determine the language
                        # Look at multiple lines to guess the language more accurately
                        first_code_line = lines[i].strip()
                        # Look ahead at more lines for better detection
                        code_sample = []
                        temp_i = i
                        while temp_i < len(lines) and temp_i < i + 10 and (lines[temp_i].startswith(code_indent) or not lines[temp_i].strip()):
                            if lines[temp_i].strip():
                                code_sample.append(lines[temp_i].strip())
                            temp_i += 1
                        
                        code_text = ' '.join(code_sample).lower()
                        language = 'php'  # default to php for CakePHP docs
                        
                        # Detect bash/shell commands
                        if first_code_line.startswith('bin/cake') or first_code_line.startswith('composer') or first_code_line.startswith('$') or first_code_line.startswith('user@'):
                            language = 'bash'
                        # Detect SQL
                        elif first_code_line.startswith('SELECT') or first_code_line.startswith('CREATE') or first_code_line.startswith('INSERT') or first_code_line.startswith('UPDATE') or first_code_line.startswith('DELETE'):
                            language = 'sql'
                        # PHP is already the default, but let's be explicit about strong indicators
                        elif first_code_line.startswith('<?php') or 'namespace' in code_text or '->' in code_text or '::' in code_text or first_code_line.startswith('class ') or first_code_line.startswith('public ') or first_code_line.startswith('private ') or first_code_line.startswith('protected '):
                            language = 'php'
                        
                        # Add explicit code-block directive
                        result.append('')
                        result.append(content_indent + '.. code-block:: ' + language)
                        result.append('')
                        
                        # Add all the code lines with proper indentation
                        # Code blocks in RST need to be indented relative to the directive
                        code_block_indent = content_indent + '    '
                        while i < len(lines) and (lines[i].startswith(code_indent) or not lines[i].strip()):
                            if lines[i].strip():
                                # Keep the original code indentation but adjust the base
                                # Remove code_indent and add code_block_indent
                                code_content = lines[i][len(code_indent):]
                                result.append(code_block_indent + code_content)
                            else:
                                result.append(lines[i])
                            i += 1
                        
                        continue
                
                # Regular line in directive
                result.append(current_line)
                i += 1
        else:
            # Not a directive, just add the line
            result.append(line)
            i += 1
    
    return '\n'.join(result)

def convert_markers_to_html_comments(content):
    """
    Convert RST comment markers to raw HTML blocks so they pass through Pandoc.
    
    Converts:
        .. start-text
    
    To:
        .. raw:: html
        
           <!-- start-text -->
    """
    lines = content.split('\n')
    result = []
    
    for line in lines:
        # Check if this is a marker comment (RST comment with simple identifier)
        marker_match = re.match(r'^(\s*)\.\.\s+([a-zA-Z0-9_-]+)\s*$', line)
        if marker_match:
            indent = marker_match.group(1)
            marker = marker_match.group(2)
            # Convert to raw HTML block
            result.append(f'{indent}.. raw:: html')
            result.append('')
            result.append(f'{indent}   <!-- {marker} -->')
            result.append('')
        else:
            result.append(line)
    
    return '\n'.join(result)

if __name__ == '__main__':
    # Read from stdin
    content = sys.stdin.read()
    current_file = os.getenv('CURRENT_RST_FILE', '')
    
    # Convert marker comments to HTML comments first
    fixed_content = convert_markers_to_html_comments(content)
    # Convert include directives to VitePress syntax
    fixed_content = convert_include_to_vitepress(fixed_content, current_file)
    # Fix literal blocks in directives
    fixed_content = fix_literal_blocks_in_directives(fixed_content)
    
    # Output the result
    sys.stdout.write(fixed_content)
