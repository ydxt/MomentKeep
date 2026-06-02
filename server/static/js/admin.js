// 管理后台自定义JavaScript

// 页面加载完成后执行
document.addEventListener('DOMContentLoaded', function() {
    console.log('管理后台加载完成');
    
    // 初始化侧边栏切换
    initSidebarToggle();
    
    // 初始化表格排序
    initTableSorting();
    
    // 初始化数据统计图表（如果有）
    initCharts();
});

// 初始化侧边栏切换
function initSidebarToggle() {
    const sidebarToggle = document.querySelector('.navbar-toggler');
    const sidebar = document.querySelector('.sidebar');
    
    if (sidebarToggle && sidebar) {
        sidebarToggle.addEventListener('click', function() {
            sidebar.classList.toggle('show');
        });
    }
}

// 初始化表格排序
function initTableSorting() {
    const tables = document.querySelectorAll('.table');
    
    tables.forEach(table => {
        const headers = table.querySelectorAll('thead th');
        headers.forEach((header, index) => {
            header.addEventListener('click', function() {
                sortTable(table, index);
            });
        });
    });
}

// 表格排序功能
function sortTable(table, columnIndex) {
    const tbody = table.querySelector('tbody');
    const rows = Array.from(tbody.querySelectorAll('tr'));
    
    // 确定排序方向
    const isAscending = this.ascending !== true;
    this.ascending = isAscending;
    
    // 排序行
    rows.sort((a, b) => {
        const aVal = a.cells[columnIndex].textContent;
        const bVal = b.cells[columnIndex].textContent;
        
        // 尝试数字排序
        const aNum = parseFloat(aVal);
        const bNum = parseFloat(bVal);
        
        if (!isNaN(aNum) && !isNaN(bNum)) {
            return isAscending ? aNum - bNum : bNum - aNum;
        }
        
        // 字符串排序
        return isAscending 
            ? aVal.localeCompare(bVal) 
            : bVal.localeCompare(aVal);
    });
    
    // 重新插入行
    rows.forEach(row => tbody.appendChild(row));
}

// 初始化数据统计图表
function initCharts() {
    // 这里可以添加图表初始化代码，例如使用Chart.js等库
    console.log('图表初始化');
}
