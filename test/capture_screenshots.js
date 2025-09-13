const { chromium } = require('playwright');
const path = require('path');
const fs = require('fs');

// Ensure screenshots directory exists
const screenshotsDir = path.join(__dirname, 'screenshots');
if (!fs.existsSync(screenshotsDir)) {
  fs.mkdirSync(screenshotsDir, { recursive: true });
}

async function captureScreenshots() {
  console.log('🚀 Starting Flutter KeyCheck HTML Report Screenshot Capture');
  console.log('=' * 80);
  
  // Launch browser
  const browser = await chromium.launch({ 
    headless: true 
  });
  
  // Define viewports
  const viewports = {
    desktop: { width: 1920, height: 1080, label: 'desktop' },
    mobile: { width: 375, height: 812, label: 'mobile' }
  };
  
  // Report file path
  const reportPath = path.join(__dirname, '..', 'enhanced_demo_report_simple.html');
  const reportUrl = `file://${reportPath}`;
  
  // Screenshot scenarios
  const scenarios = [
    {
      name: '01_dashboard_overview',
      description: 'Executive Dashboard - Main Overview',
      elements: 'Health Score, System Status, Priority Actions, Key Metrics',
      actions: async (page) => {
        // Just capture the initial state
      }
    },
    {
      name: '02_coverage_heatmap',
      description: 'Coverage Heatmap Section',
      elements: 'File coverage visualization, Directory structure, Color-coded coverage levels',
      actions: async (page) => {
        // Scroll to coverage section if exists
        const coverageSection = await page.$('.coverage-section, .heatmap-container');
        if (coverageSection) {
          await coverageSection.scrollIntoViewIfNeeded();
        }
      }
    },
    {
      name: '03_key_analysis_table',
      description: 'Key Analysis Table',
      elements: 'Key listing, Status badges, Categories, File locations, Actions',
      actions: async (page) => {
        // Scroll to key analysis section
        const tableSection = await page.$('.key-analysis-section, .keys-table, table');
        if (tableSection) {
          await tableSection.scrollIntoViewIfNeeded();
        }
      }
    },
    {
      name: '04_search_functionality',
      description: 'Search and Filter Controls',
      elements: 'Search box, Status filter dropdown, Category filter dropdown',
      actions: async (page) => {
        // Focus on search controls
        const searchBox = await page.$('#search-box, input[type="text"], .search-box');
        if (searchBox) {
          await searchBox.scrollIntoViewIfNeeded();
          await searchBox.click();
          await page.keyboard.type('button');
          await page.waitForTimeout(500);
        }
      }
    },
    {
      name: '05_filter_dropdowns',
      description: 'Filter Controls',
      elements: 'Status filter, Category filter, Applied filters',
      actions: async (page) => {
        // Open filter dropdowns
        const statusFilter = await page.$('#status-filter, select:first-of-type, .filter-select');
        if (statusFilter) {
          await statusFilter.scrollIntoViewIfNeeded();
          await statusFilter.click();
          await page.waitForTimeout(500);
        }
      }
    },
    {
      name: '06_key_detail_modal',
      description: 'Key Detail View',
      elements: 'Key information, Code context, Location details, Related keys',
      actions: async (page) => {
        // Try to click on a View button to open modal
        const viewBtn = await page.$('.action-btn:has-text("View"), button:has-text("View")');
        if (viewBtn) {
          await viewBtn.click();
          await page.waitForTimeout(1000);
        } else {
          // If no modal, just capture the table with details
          const firstRow = await page.$('tbody tr:first-child');
          if (firstRow) {
            await firstRow.scrollIntoViewIfNeeded();
          }
        }
      }
    },
    {
      name: '07_code_context',
      description: 'Code Context Display',
      elements: 'Syntax highlighted code, Line numbers, Key usage highlight, File path',
      actions: async (page) => {
        // Look for code blocks
        const codeBlock = await page.$('pre, code, .code-block, .code-context');
        if (codeBlock) {
          await codeBlock.scrollIntoViewIfNeeded();
        }
      }
    },
    {
      name: '08_export_functionality',
      description: 'Export Options',
      elements: 'Export buttons, Format selection, Download options',
      actions: async (page) => {
        // Look for export controls
        const exportBtn = await page.$('button:has-text("Export"), .export-btn, a[download]');
        if (exportBtn) {
          await exportBtn.scrollIntoViewIfNeeded();
          await exportBtn.hover();
          await page.waitForTimeout(500);
        }
      }
    },
    {
      name: '09_theme_switcher_light',
      description: 'Theme Switcher - Light Mode',
      elements: 'Theme toggle button, Light color scheme, UI in light mode',
      actions: async (page) => {
        // Try to switch to light theme if available
        const themeToggle = await page.$('.theme-toggle, button:has-text("Theme"), [aria-label*="theme"]');
        if (themeToggle) {
          await themeToggle.click();
          await page.waitForTimeout(500);
        }
        // Apply light theme CSS if no toggle
        await page.evaluate(() => {
          document.documentElement.style.setProperty('--background', '#FFFFFF');
          document.documentElement.style.setProperty('--text-primary', '#1F2937');
          document.documentElement.style.setProperty('--text-secondary', '#6B7280');
          document.documentElement.classList.add('light-theme');
        });
      }
    },
    {
      name: '10_theme_switcher_dark',
      description: 'Theme Switcher - Dark Mode',
      elements: 'Theme toggle button, Dark color scheme, UI in dark mode',
      actions: async (page) => {
        // Reset to dark theme
        await page.evaluate(() => {
          document.documentElement.style.setProperty('--background', '#0F172A');
          document.documentElement.style.setProperty('--text-primary', '#F8FAFC');
          document.documentElement.style.setProperty('--text-secondary', '#CBD5E1');
          document.documentElement.classList.remove('light-theme');
          document.documentElement.classList.add('dark-theme');
        });
      }
    },
    {
      name: '11_responsive_mobile_menu',
      description: 'Mobile Menu (Mobile Only)',
      elements: 'Hamburger menu, Mobile navigation, Touch-friendly controls',
      actions: async (page) => {
        // Mobile-specific interactions
        const mobileMenu = await page.$('.mobile-menu, .hamburger, [aria-label*="menu"]');
        if (mobileMenu) {
          await mobileMenu.click();
          await page.waitForTimeout(500);
        }
      }
    },
    {
      name: '12_scroll_to_top',
      description: 'Scroll Controls',
      elements: 'Scroll to top button, Page navigation, Smooth scrolling',
      actions: async (page) => {
        // Scroll down first to show scroll button
        await page.evaluate(() => window.scrollTo(0, document.body.scrollHeight));
        await page.waitForTimeout(500);
        const scrollBtn = await page.$('.scroll-to-top, button[aria-label*="scroll"], [title*="top"]');
        if (scrollBtn) {
          await scrollBtn.scrollIntoViewIfNeeded();
        }
      }
    }
  ];
  
  // Capture screenshots for each viewport
  for (const [viewportName, viewport] of Object.entries(viewports)) {
    console.log(`\n📱 Capturing ${viewport.label} screenshots (${viewport.width}x${viewport.height})`);
    
    const context = await browser.newContext({
      viewport: { width: viewport.width, height: viewport.height },
      deviceScaleFactor: 2, // High quality screenshots
    });
    
    const page = await context.newPage();
    await page.goto(reportUrl, { waitUntil: 'networkidle' });
    
    // Wait for initial render
    await page.waitForTimeout(1000);
    
    for (const scenario of scenarios) {
      // Skip mobile-only scenarios on desktop
      if (viewportName === 'desktop' && scenario.name.includes('mobile_menu')) {
        continue;
      }
      
      console.log(`  📸 ${scenario.name} - ${scenario.description}`);
      
      // Reset to top
      await page.evaluate(() => window.scrollTo(0, 0));
      await page.waitForTimeout(200);
      
      // Execute scenario actions
      await scenario.actions(page);
      
      // Capture screenshot
      const filename = `${scenario.name}_${viewport.label}.png`;
      const filepath = path.join(screenshotsDir, filename);
      
      await page.screenshot({
        path: filepath,
        fullPage: false, // Capture viewport
        animations: 'disabled'
      });
      
      console.log(`     ✅ Saved: ${filename}`);
      console.log(`     📝 Elements: ${scenario.elements}`);
    }
    
    await context.close();
  }
  
  await browser.close();
  
  console.log('\n' + '=' * 80);
  console.log('✨ Screenshot capture complete!');
  console.log(`📁 Screenshots saved to: ${screenshotsDir}`);
  console.log(`📊 Total screenshots: ${scenarios.length * 2} (desktop + mobile)`);
}

// Run the capture
captureScreenshots().catch(console.error);