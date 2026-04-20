# Building GitBook Documentation

This file contains instructions for building and publishing Thesauros documentation in GitBook format.

## Installing GitBook CLI

### Global Installation (Recommended)

```bash
npm install -g gitbook-cli
```

### Verify Installation

```bash
gitbook --version
```

## Building Documentation

### 1. Install Dependencies

```bash
# In the docs folder
gitbook install
```

### 2. Preview

```bash
# Start local server for preview
gitbook serve

# Documentation will be available at: http://localhost:4000
```

### 3. Build Static Files

```bash
# Build for website
gitbook build

# Build to _book folder
gitbook build ./ _book
```

### 4. Build in Various Formats

```bash
# Build to PDF
gitbook pdf ./ ./rebalance-finance-docs.pdf

# Build to EPUB
gitbook epub ./ ./rebalance-finance-docs.epub

# Build to MOBI
gitbook mobi ./ ./rebalance-finance-docs.mobi
```

## Publishing

### GitHub Pages

1. Create a `gh-pages` branch:
```bash
git checkout -b gh-pages
```

2. Copy built files:
```bash
cp -r _book/* .
```

3. Add and commit files:
```bash
git add .
git commit -m "Update documentation"
git push origin gh-pages
```

4. Configure GitHub Pages in repository settings.

### Netlify

1. Create a `netlify.toml` file in the project root:
```toml
[build]
  publish = "docs/_book"
  command = "cd docs && gitbook build"

[build.environment]
  NODE_VERSION = "16"
```

2. Connect repository to Netlify.

### Vercel

1. Create a `vercel.json` file in the project root:
```json
{
  "builds": [
    {
      "src": "docs/_book/**",
      "use": "@vercel/static"
    }
  ],
  "routes": [
    {
      "src": "/(.*)",
      "dest": "/docs/_book/$1"
    }
  ]
}
```

2. Connect repository to Vercel.

## Automation

### GitHub Actions

Create a `.github/workflows/docs.yml` file:

```yaml
name: Build and Deploy Documentation

on:
  push:
    branches: [ main ]
    paths: [ 'docs/**' ]
  pull_request:
    branches: [ main ]
    paths: [ 'docs/**' ]

jobs:
  build-docs:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Setup Node.js
      uses: actions/setup-node@v3
      with:
        node-version: '16'
        cache: 'npm'
    
    - name: Install GitBook
      run: npm install -g gitbook-cli
    
    - name: Install dependencies
      run: |
        cd docs
        gitbook install
    
    - name: Build documentation
      run: |
        cd docs
        gitbook build
    
    - name: Deploy to GitHub Pages
      if: github.ref == 'refs/heads/main'
      uses: peaceiris/actions-gh-pages@v3
      with:
        github_token: ${{ secrets.GITHUB_TOKEN }}
        publish_dir: ./docs/_book
```

### Local Script

Create a `scripts/build-docs.sh` file:

```bash
#!/bin/bash

echo "Building Thesauros documentation..."

# Navigate to docs folder
cd docs

# Install dependencies
echo "Installing dependencies..."
gitbook install

# Build documentation
echo "Building documentation..."
gitbook build

# Build to PDF
echo "Building PDF..."
gitbook pdf ./ ../rebalance-finance-docs.pdf

# Build to EPUB
echo "Building EPUB..."
gitbook epub ./ ../rebalance-finance-docs.epub

echo "Documentation built successfully!"
echo "Files generated:"
echo "- docs/_book/ (website)"
echo "- rebalance-finance-docs.pdf"
echo "- rebalance-finance-docs.epub"
```

Make the script executable:
```bash
chmod +x scripts/build-docs.sh
```

## Plugins

### Installed Plugins

- `expandable-chapters` - collapsible chapters
- `search` - documentation search
- `copy-code-button` - code copy button
- `theme-default` - default theme
- `highlight` - syntax highlighting
- `sharing` - social media buttons
- `fontsettings` - font settings
- `livereload` - automatic reload
- `mermaid-gb3` - Mermaid diagrams

### Installing Additional Plugins

```bash
# Install plugin
gitbook install plugin-name

# Add to book.json
{
  "plugins": [
    "plugin-name"
  ]
}
```

## Customization

### Styles

Create a `docs/styles/website.css` file:

```css
/* Custom styles for website */
.book-summary {
    background-color: #f8f9fa;
}

.book-summary ul.summary li a {
    color: #333;
}

.book-summary ul.summary li.active > a {
    color: #007bff;
    background-color: #e9ecef;
}

/* Code styles */
.markdown-section pre {
    background-color: #f6f8fa;
    border: 1px solid #e1e4e8;
}

.markdown-section code {
    background-color: #f6f8fa;
    color: #e36209;
}
```

### Templates

Create a `docs/_layouts/website/summary.html` file:

```html
{% extends "website/summary.html" %}

{% block book_summary %}
<nav role="navigation">
    <ul class="summary">
        {% set _divider = false %}
        {% if options.links.sidebar %}
        {% for linkTitle, link in options.links.sidebar %}
        {% set _divider = true %}
        <li>
            <a href="{{ link }}" target="blank" class="custom-link">{{ linkTitle }}</a>
        </li>
        {% endfor %}
        {% endif %}

        {% for part in summary.parts %}
        {% if part.title %}
        <li class="chapter {% if part.current %}active{% endif %}" data-level="{{ part.level }}" {% if part.path %}data-path="{{ part.path|resolveFile }}"{% endif %}>
            {% if part.path %}
            <a href="{{ part.path|resolveFile }}{% if part.anchor %}#{{ part.anchor }}{% endif %}">
                <i class="fa fa-check"></i> {{ part.title }}
            </a>
            {% else %}
            <span><b>{{ part.level }}.</b> {{ part.title }}</span>
            {% endif %}

            {% if part.articles %}
            <ul class="articles">
                {% for article in part.articles %}
                <li class="chapter {% if article.current %}active{% endif %}" data-level="{{ article.level }}" {% if article.path %}data-path="{{ article.path|resolveFile }}"{% endif %}>
                    {% if article.path %}
                    <a href="{{ article.path|resolveFile }}{% if article.anchor %}#{{ article.anchor }}{% endif %}">
                        <i class="fa fa-check"></i> {{ article.title }}
                    </a>
                    {% else %}
                    <span><b>{{ article.level }}.</b> {{ article.title }}</span>
                    {% endif %}
                </li>
                {% endfor %}
            </ul>
            {% endif %}
        </li>
        {% endif %}
        {% endfor %}
    </ul>
</nav>
{% endblock %}
```

## Troubleshooting

### Common Issues

1. **Error "gitbook: command not found"**
   - Make sure GitBook CLI is installed globally
   - Try reinstalling: `npm uninstall -g gitbook-cli && npm install -g gitbook-cli`

2. **Plugin Errors**
   - Delete `node_modules` folder and reinstall: `rm -rf node_modules && gitbook install`

3. **Encoding Issues**
   - Make sure files are saved in UTF-8
   - Add to `book.json`: `"language": "en"`

4. **Mermaid Issues**
   - Make sure `mermaid-gb3` plugin is installed
   - Check diagram syntax

### Logs

```bash
# Detailed logs
gitbook serve --log=debug

# Build logs
gitbook build --log=debug
```

## Updating Documentation

### Automatic Updates

1. Make changes to documentation files
2. Commit changes
3. Push to repository
4. GitHub Actions will automatically build and publish documentation

### Manual Updates

```bash
# Build
cd docs
gitbook build

# Publish (depending on platform)
# GitHub Pages
git checkout gh-pages
cp -r _book/* .
git add .
git commit -m "Update documentation"
git push origin gh-pages
```

## Contact

If you encounter issues with documentation:

- Create an issue on GitHub
- Contact the development team
- Check GitBook documentation: https://toolchain.gitbook.com/ 