/// Enhanced Syntax Highlighter for Flutter KeyCheck Premium Reporter
/// Implements Priority 1 features from FUTURE_ENHANCEMENT_ROADMAP.md
class EnhancedSyntaxHighlighter {
  
  /// Generates enhanced JavaScript for advanced Dart syntax highlighting
  static String generateEnhancedHighlightingScript() {
    return r'''
    <script>
    // Enhanced Dart Syntax Highlighting - Priority 1 Features
    
    // ИСПРАВЛЕНИЕ: Безопасная инициализация Prism.js
    if (typeof Prism === 'undefined' || !Prism.languages) {
      console.warn('Prism.js not loaded properly');
      return;
    }
    
    // Безопасное создание языка Dart
    Prism.languages.dart = {
      'comment': [
        // Multi-line comments with nesting support
        {
          pattern: /\/\*[\s\S]*?\*\//,
          greedy: true,
          inside: {
            'todo': {
              pattern: /\b(?:TODO|FIXME|NOTE|HACK|BUG)\b/,
              alias: 'important'
            }
          }
        },
        // Single-line comments
        {
          pattern: /\/\/.*$/m,
          inside: {
            'todo': {
              pattern: /\b(?:TODO|FIXME|NOTE|HACK|BUG)\b/,
              alias: 'important'
            }
          }
        }
      ],
      
      // String interpolation highlighting
      'string': [
        // Raw strings
        {
          pattern: /r(["'])(?:(?!\1)[^\r\n\\]|\\.)*\1/,
          greedy: true,
          alias: 'raw-string'
        },
        // Regular strings with interpolation
        {
          pattern: /(["'])(?:\\.|(?!\1)[^\\\r\n])*\1/,
          greedy: true,
          inside: {
            'interpolation': {
              pattern: /\$\{[^}]*\}/,
              inside: {
                'punctuation': /^\$\{|\}$/,
                'expression': {
                  pattern: /[\s\S]+/,
                  inside: null // Will be replaced with Prism.languages.dart
                }
              }
            },
            'variable': {
              pattern: /\$\w+/,
              alias: 'variable'
            }
          }
        }
      ],
      
      // Generics support
      'generic': {
        pattern: /<[\w\s,<>?]+>/,
        inside: {
          'type': /\b[A-Z]\w*/,
          'punctuation': /[<>?,]/,
          'keyword': /\b(?:extends|super)\b/
        }
      },
      
      // Annotations with parameters
      'annotation': {
        pattern: /@\w+(?:\([^)]*\))?/,
        alias: 'important',
        inside: {
          'punctuation': /[@()]/
        }
      },
      
      // Null safety operators
      'null-safety': [
        {
          pattern: /\?\?=/,
          alias: 'operator assignment-operator'
        },
        {
          pattern: /\?\?/,
          alias: 'operator null-coalescing'
        },
        {
          pattern: /\?\./,
          alias: 'operator null-aware'
        },
        {
          pattern: /!/,
          alias: 'operator null-assertion'
        }
      ],
      
      // Enhanced keywords including async/await
      'keyword': /\b(?:return|class|interface|extends|implements|mixin|with|abstract|static|final|const|var|late|required|void|if|else|for|while|do|switch|case|break|continue|try|catch|finally|throw|rethrow|assert|new|this|super|null|true|false|import|export|library|part|as|show|hide|typedef|enum|async|await|yield|sync|factory|operator|covariant|deferred|external|get|set|native)\b/,
      
      // Flutter-specific types
      'class-name': /\b(?:String|int|double|bool|num|dynamic|Object|List|Map|Set|Future|Stream|Completer|Key|Widget|State|StatefulWidget|StatelessWidget|BuildContext|Container|Column|Row|Text|ValueKey|GlobalKey|UniqueKey|ObjectKey|MaterialApp|Scaffold|AppBar|FloatingActionButton|ElevatedButton|TextButton|OutlinedButton|IconButton|GestureDetector|InkWell|Padding|Margin|SizedBox|Expanded|Flexible|Center|Align|Stack|Positioned|Card|Material|Theme|ThemeData|Color|Colors|MediaQuery|Navigator|Route|MaterialPageRoute|Animation|AnimationController|Tween|Duration|DateTime|File|Directory|HttpClient|HttpRequest|HttpResponse)\b/,
      
      // Enhanced function detection
      'function': {
        pattern: /\b[a-zA-Z_]\w*(?=\s*[(<])/,
        inside: {
          'punctuation': /[()]/
        }
      },
      
      // Numbers with scientific notation
      'number': /\b\d+(?:\.\d+)?(?:[eE][+-]?\d+)?\b/,
      
      // Operators including null-safe ones
      'operator': /[+\-*/%=<>!&|^~?:]+|\bis\b|\bas\b/,
      
      'punctuation': /[{}\[\]();,:.]/ 
    });
    
    // Copy string interpolation pattern reference
    Prism.languages.dart.string.forEach(function(stringDef) {
      if (stringDef.inside && stringDef.inside.interpolation) {
        stringDef.inside.interpolation.inside.expression.inside = Prism.languages.dart;
      }
    });
    
    // Enhanced Copy to Clipboard with line selection
    function initializeEnhancedCopy() {
      document.addEventListener('DOMContentLoaded', function() {
        // Add copy button to each code block
        document.querySelectorAll('pre[data-code-context]').forEach(function(pre) {
          const copyBtn = document.createElement('button');
          copyBtn.className = 'copy-btn enhanced-copy';
          copyBtn.innerHTML = '<i class="fas fa-copy"></i>';
          copyBtn.title = 'Copy code block';
          
          pre.style.position = 'relative';
          pre.appendChild(copyBtn);
          
          copyBtn.addEventListener('click', function() {
            copyCodeBlock(pre);
          });
        });
        
        // Add line selection functionality
        document.querySelectorAll('.line-container').forEach(function(line, index) {
          line.addEventListener('click', function(e) {
            if (e.shiftKey && window.lastSelectedLine !== undefined) {
              selectLineRange(window.lastSelectedLine, index);
            } else {
              selectSingleLine(index);
              window.lastSelectedLine = index;
            }
          });
        });
      });
    }
    
    function copyCodeBlock(pre) {
      const codeContent = pre.querySelector('code');
      const text = codeContent.textContent || codeContent.innerText;
      
      navigator.clipboard.writeText(text).then(function() {
        showCopyFeedback(pre.querySelector('.copy-btn'));
      });
    }
    
    function selectSingleLine(lineIndex) {
      // Clear previous selections
      document.querySelectorAll('.line-container.selected').forEach(function(line) {
        line.classList.remove('selected');
      });
      
      const line = document.querySelectorAll('.line-container')[lineIndex];
      if (line) {
        line.classList.add('selected');
      }
    }
    
    function selectLineRange(startIndex, endIndex) {
      const start = Math.min(startIndex, endIndex);
      const end = Math.max(startIndex, endIndex);
      const lines = document.querySelectorAll('.line-container');
      
      // Clear previous selections
      lines.forEach(function(line) {
        line.classList.remove('selected');
      });
      
      // Select range
      for (let i = start; i <= end && i < lines.length; i++) {
        lines[i].classList.add('selected');
      }
    }
    
    function showCopyFeedback(button) {
      const originalIcon = button.innerHTML;
      button.innerHTML = '<i class="fas fa-check"></i>';
      button.style.color = '#10b981';
      
      setTimeout(function() {
        button.innerHTML = originalIcon;
        button.style.color = '';
      }, 2000);
    }
    
    // Collapsible Code Blocks
    function initializeCollapsibleBlocks() {
      document.addEventListener('DOMContentLoaded', function() {
        // Find code blocks that can be collapsed (classes, methods, etc.)
        document.querySelectorAll('pre[data-code-context]').forEach(function(pre) {
          addCollapseButtons(pre);
        });
      });
    }
    
    function addCollapseButtons(pre) {
      const lines = pre.querySelectorAll('.line-container');
      const collapsePoints = [];
      
      lines.forEach(function(line, index) {
        const content = line.textContent || line.innerText;
        
        // Detect collapsible structures
        if (content.match(/^\\s*(?:class|enum|mixin|extension)\\s+\\w+/)) {
          collapsePoints.push({
            type: 'class',
            startLine: index,
            content: content.trim()
          });
        } else if (content.match(/^\\s*(?:@override\\s+)?(?:Widget|void|Future|String|int|double|bool)\\s+\\w+\\s*\\(/)) {
          collapsePoints.push({
            type: 'method',
            startLine: index,
            content: content.trim()
          });
        }
      });
      
      // Add collapse buttons
      collapsePoints.forEach(function(point) {
        const line = lines[point.startLine];
        if (line) {
          const collapseBtn = document.createElement('button');
          collapseBtn.className = 'collapse-btn';
          collapseBtn.innerHTML = '[-]';
          collapseBtn.title = 'Collapse ' + point.type;
          
          line.querySelector('.line-content').prepend(collapseBtn);
          
          collapseBtn.addEventListener('click', function() {
            toggleCollapse(point.startLine, lines);
          });
        }
      });
    }
    
    function toggleCollapse(startLine, lines) {
      const startLineEl = lines[startLine];
      const collapseBtn = startLineEl.querySelector('.collapse-btn');
      const isCollapsed = collapseBtn.textContent === '[+]';
      
      if (isCollapsed) {
        // Expand
        collapseBtn.textContent = '[-]';
        showCollapsedLines(startLine, lines);
      } else {
        // Collapse
        collapseBtn.textContent = '[+]';
        hideCollapsedLines(startLine, lines);
      }
    }
    
    function hideCollapsedLines(startLine, lines) {
      let braceCount = 0;
      let foundOpenBrace = false;
      
      for (let i = startLine + 1; i < lines.length; i++) {
        const content = lines[i].textContent || lines[i].innerText;
        
        // Count braces to find the end of the block
        for (let char of content) {
          if (char === '{') {
            braceCount++;
            foundOpenBrace = true;
          } else if (char === '}') {
            braceCount--;
          }
        }
        
        if (foundOpenBrace) {
          lines[i].style.display = 'none';
          lines[i].classList.add('collapsed-line');
          
          if (braceCount === 0) {
            break; // End of block
          }
        }
      }
    }
    
    function showCollapsedLines(startLine, lines) {
      for (let i = startLine + 1; i < lines.length; i++) {
        if (lines[i].classList.contains('collapsed-line')) {
          lines[i].style.display = 'flex';
          lines[i].classList.remove('collapsed-line');
        }
      }
    }
    
    // Initialize all enhanced features
    initializeEnhancedCopy();
    initializeCollapsibleBlocks();
    
    </script>
    ''';
  }
  
  /// Generates enhanced CSS for improved syntax highlighting
  static String generateEnhancedStyling() {
    return '''
    <style>
    /* Enhanced Syntax Highlighting Styles - Priority 1 Features */
    
    /* Multi-line comment improvements */
    .token.comment .token.todo,
    .token.comment .token.important {
      background: rgba(251, 191, 36, 0.2);
      color: #fbbf24;
      padding: 2px 4px;
      border-radius: 3px;
      font-weight: 600;
    }
    
    /* String interpolation styling */
    .token.string .token.interpolation {
      background: rgba(34, 197, 94, 0.1);
      border-radius: 3px;
      padding: 1px 2px;
    }
    
    .token.string .token.interpolation .token.punctuation {
      color: #22c55e;
      font-weight: 600;
    }
    
    .token.string .token.variable {
      color: #3b82f6;
      font-weight: 500;
    }
    
    .token.string.raw-string {
      color: #a78bfa;
      font-style: italic;
    }
    
    /* Generics highlighting */
    .token.generic {
      color: #06b6d4;
    }
    
    .token.generic .token.type {
      color: #0891b2;
      font-weight: 600;
    }
    
    /* Annotations styling */
    .token.annotation {
      color: #f59e0b;
      font-weight: 500;
    }
    
    .token.annotation .token.punctuation {
      color: #d97706;
    }
    
    /* Null safety operators */
    .token.null-safety {
      color: #ef4444;
      font-weight: 700;
    }
    
    .token.operator.null-coalescing {
      color: #f97316;
      font-weight: 600;
    }
    
    .token.operator.null-aware {
      color: #eab308;
      font-weight: 600;
    }
    
    .token.operator.null-assertion {
      color: #dc2626;
      font-weight: 700;
      font-size: 1.1em;
    }
    
    /* Enhanced copy button */
    .copy-btn.enhanced-copy {
      position: absolute;
      top: 12px;
      right: 12px;
      background: rgba(51, 65, 85, 0.9);
      border: 1px solid rgba(71, 85, 105, 0.5);
      color: #e2e8f0;
      padding: 8px 12px;
      border-radius: 6px;
      cursor: pointer;
      font-size: 12px;
      transition: all 0.2s ease;
      backdrop-filter: blur(8px);
      z-index: 10;
    }
    
    .copy-btn.enhanced-copy:hover {
      background: rgba(71, 85, 105, 0.9);
      color: #60a5fa;
      transform: translateY(-1px);
      box-shadow: 0 4px 12px rgba(0, 0, 0, 0.3);
    }
    
    /* Line selection styling */
    .line-container.selected {
      background: rgba(59, 130, 246, 0.1);
      border-left: 3px solid #3b82f6;
    }
    
    .line-container:hover {
      background: rgba(71, 85, 105, 0.1);
      cursor: pointer;
    }
    
    /* Collapsible code blocks */
    .collapse-btn {
      background: rgba(71, 85, 105, 0.7);
      border: none;
      color: #94a3b8;
      padding: 2px 6px;
      margin-right: 8px;
      border-radius: 3px;
      cursor: pointer;
      font-family: monospace;
      font-size: 11px;
      transition: all 0.2s ease;
    }
    
    .collapse-btn:hover {
      background: rgba(71, 85, 105, 1);
      color: #e2e8f0;
    }
    
    .collapsed-line {
      display: none !important;
    }
    
    /* Mobile responsiveness improvements */
    @media (max-width: 768px) {
      .copy-btn.enhanced-copy {
        position: static;
        display: block;
        margin: 8px 0;
        width: 100%;
        text-align: center;
      }
      
      .line-container {
        padding: 8px 4px;
        font-size: 12px;
      }
      
      .collapse-btn {
        font-size: 10px;
        padding: 1px 4px;
      }
      
      pre[data-code-context] {
        margin: 8px 0;
        padding: 12px 8px;
      }
    }
    
    /* Touch-friendly improvements */
    @media (pointer: coarse) {
      .line-container {
        min-height: 44px;
        align-items: center;
      }
      
      .collapse-btn {
        min-width: 44px;
        min-height: 44px;
        display: flex;
        align-items: center;
        justify-content: center;
      }
      
      .copy-btn.enhanced-copy {
        min-height: 44px;
        font-size: 14px;
      }
    }
    
    /* Performance optimizations for large files */
    .virtual-scroll {
      height: 400px;
      overflow-y: auto;
    }
    
    .line-container {
      contain: layout;
      will-change: transform;
    }
    
    /* Accessibility improvements */
    .copy-btn.enhanced-copy:focus {
      outline: 2px solid #60a5fa;
      outline-offset: 2px;
    }
    
    .collapse-btn:focus {
      outline: 1px solid #94a3b8;
      outline-offset: 1px;
    }
    
    .line-container[aria-selected="true"] {
      background: rgba(59, 130, 246, 0.2);
    }
    
    /* High contrast mode support */
    @media (prefers-contrast: high) {
      .token.comment { color: #9ca3af; }
      .token.string { color: #86efac; }
      .token.keyword { color: #c084fc; }
      .token.class-name { color: #7dd3fc; }
      .token.function { color: #fbbf24; }
    }
    
    /* Reduced motion support */
    @media (prefers-reduced-motion: reduce) {
      .copy-btn.enhanced-copy,
      .collapse-btn {
        transition: none;
      }
      
      .copy-btn.enhanced-copy:hover {
        transform: none;
      }
    }
    </style>
    ''';
  }
}