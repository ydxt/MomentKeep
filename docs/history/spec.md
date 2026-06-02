# 日记复选框插入问题修复规范

## 问题描述

在日记编辑器中插入复选框后存在以下问题：
1. 插入复选框后没有输入光标闪烁
2. 尝试输入内容没有任何反应
3. 鼠标点击复选框位置后，光标位置不对
4. 使用方向键移动光标后输入内容，复选框出现乱码

## 问题分析

### 代码结构分析

经过深入分析，发现代码中存在**两个插入复选框的位置**：

#### 位置1：第 3615-3646 行（绘图工具栏）
```dart
IconButton(
  icon: Icon(Icons.check_box_outlined, ...),
  onPressed: () {
    final selection = _controller.selection;
    final checkboxId = DateTime.now().millisecondsSinceEpoch.toString();
    final checkboxData = jsonEncode({'id': checkboxId, 'checked': false});
    
    _controller.replaceText(
        selection.start,
        selection.extentOffset - selection.start,
        flutter_quill.BlockEmbed.custom(
            flutter_quill.CustomBlockEmbed('checkbox', checkboxData)),
        null);
    
    _controller.document.insert(selection.start + 1, ' ');
    
    _controller.updateSelection(
      TextSelection.collapsed(offset: selection.start + 2),
      flutter_quill.ChangeSource.local,
    );
    _quillFocusNode.requestFocus();
  },
)
```

#### 位置2：第 3750-3770 行（主工具栏）
```dart
IconButton(
  icon: Icon(Icons.check_box_outlined, ...),
  onPressed: () {
    final selection = _controller.selection;
    final checkboxId = DateTime.now().millisecondsSinceEpoch.toString();
    final checkboxData = jsonEncode({'id': checkboxId, 'checked': false});
    
    _controller.replaceText(
        selection.start,
        selection.extentOffset - selection.start,
        flutter_quill.BlockEmbed.custom(
            flutter_quill.CustomBlockEmbed('checkbox', checkboxData)),
        TextSelection.collapsed(offset: selection.start + 1));
  },
)
```

### 问题根源

1. **两处代码不一致**：位置1尝试插入空格，位置2没有

2. **`_handleAutoCheckbox` 监听器干扰**：
   - 该监听器在文档变化时触发
   - 可能会修改或覆盖插入操作

3. **`_isHandlingCheckbox` 标志问题**：
   - 该标志用于防止无限循环
   - 但在手动插入复选框时没有设置

4. **文档变化监听器链**：
   ```dart
   _documentChangesSubscription = _controller.document.changes.listen((event) {
     _onDocumentChange();
     _handleAutoCheckbox(event);
   });
   ```

5. **空格插入被覆盖**：
   - 日志显示复选框后只有 `\n`，没有空格
   - 说明 `_controller.document.insert` 被某些操作覆盖

### 对比图片插入（成功案例）

```dart
// 图片插入代码（第 2211-2222 行）
_controller.replaceText(
  selection.start,
  selection.extentOffset - selection.start,
  flutter_quill.BlockEmbed.image(newPath),
  TextSelection.collapsed(offset: selection.start + 1),
);
_controller.updateSelection(
  TextSelection.collapsed(offset: selection.start + 1),
  flutter_quill.ChangeSource.local,
);
_quillFocusNode.requestFocus();
```

**关键差异**：
- 图片插入使用 `TextSelection.collapsed(offset: selection.start + 1)` 作为 `replaceText` 的第四个参数
- 复选框插入位置1使用 `null`，位置2使用正确的选择参数

## 解决方案

### 方案1：统一两处代码并设置 `_isHandlingCheckbox` 标志

```dart
IconButton(
  icon: Icon(Icons.check_box_outlined, size: 24, color: AppTheme.deepSpaceGray),
  onPressed: () {
    final selection = _controller.selection;
    final checkboxId = DateTime.now().millisecondsSinceEpoch.toString();
    final checkboxData = jsonEncode({'id': checkboxId, 'checked': false});
    
    // 设置标志防止 _handleAutoCheckbox 干扰
    _isHandlingCheckbox = true;
    try {
      _controller.replaceText(
          selection.start,
          selection.extentOffset - selection.start,
          flutter_quill.BlockEmbed.custom(
              flutter_quill.CustomBlockEmbed('checkbox', checkboxData)),
          TextSelection.collapsed(offset: selection.start + 1));
      
      // 在复选框后插入空格
      _controller.document.insert(selection.start + 1, ' ');
      
      // 设置光标到空格之后
      _controller.updateSelection(
        TextSelection.collapsed(offset: selection.start + 2),
        flutter_quill.ChangeSource.local,
      );
      
      _quillFocusNode.requestFocus();
    } finally {
      _isHandlingCheckbox = false;
    }
  },
  tooltip: '插入复选框',
),
```

### 方案2：使用与图片插入完全相同的模式

```dart
IconButton(
  icon: Icon(Icons.check_box_outlined, size: 24, color: AppTheme.deepSpaceGray),
  onPressed: () {
    final selection = _controller.selection;
    final checkboxId = DateTime.now().millisecondsSinceEpoch.toString();
    final checkboxData = jsonEncode({'id': checkboxId, 'checked': false});
    
    _isHandlingCheckbox = true;
    try {
      _controller.replaceText(
        selection.start,
        selection.extentOffset - selection.start,
        flutter_quill.BlockEmbed.custom(
            flutter_quill.CustomBlockEmbed('checkbox', checkboxData)),
        TextSelection.collapsed(offset: selection.start + 1),
      );
      
      _controller.updateSelection(
        TextSelection.collapsed(offset: selection.start + 1),
        flutter_quill.ChangeSource.local,
      );
      
      _quillFocusNode.requestFocus();
    } finally {
      _isHandlingCheckbox = false;
    }
  },
  tooltip: '插入复选框',
),
```

### 方案3：在 `_handleAutoCheckbox` 中跳过手动插入

修改 `_handleAutoCheckbox` 方法，在检测到手动插入复选框时跳过处理：

```dart
void _handleAutoCheckbox(flutter_quill.DocChange event) {
  if (_isHandlingCheckbox) return;
  // ... 其余代码
}
```

## 推荐方案

**推荐方案2**，原因：
1. 与图片插入逻辑完全一致
2. 代码简洁，不依赖额外的空格插入
3. 设置 `_isHandlingCheckbox` 标志防止监听器干扰

## 验收标准

1. 插入复选框后，光标自动出现在复选框后
2. 可以立即输入文字，无需手动点击
3. 输入文字后复选框不会出现乱码
4. 复选框功能正常（点击可切换状态）
