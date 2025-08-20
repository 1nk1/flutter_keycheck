#!/bin/bash
set -e

echo "🚀 Flutter KeyCheck Premium Demo"
echo "=================================="
echo

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}📊 Running scan with beautiful CI output...${NC}"
echo
/home/adj/.fvm/versions/3.35.1/bin/cache/dart-sdk/bin/dart run bin/flutter_keycheck.dart scan --scope workspace-only --report ci

echo
echo -e "${GREEN}✨ Generated reports:${NC}"
echo "  • Premium HTML Report: reports/premium-report.html"
echo "  • Interactive Dashboard: reports/interactive-dashboard.html"  
echo "  • CI Terminal Output: reports/key-snapshot.ci"
echo "  • JSON Data: reports/key-snapshot.json"

echo
echo -e "${YELLOW}🌟 Key Features Demonstrated:${NC}"
echo "  • Beautiful terminal output with quality gates"
echo "  • GitLab CI/CD integration ready (.gitlab-ci-example.yml)"
echo "  • Premium HTML reports with enterprise design"
echo "  • Interactive dashboard with search and filtering"
echo "  • Proper code formatting in modals"
echo "  • Reduced animations for better CI performance"

echo
echo -e "${BLUE}💡 Usage in CI/CD:${NC}"
echo "  GitLab CI: flutter_keycheck scan --report ci"
echo "  GitHub Actions: flutter_keycheck scan --report ci --no-color"
echo "  Local Development: flutter_keycheck scan --report html"

echo
echo -e "${GREEN}🎉 Demo completed successfully!${NC}"