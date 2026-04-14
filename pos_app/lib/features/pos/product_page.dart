import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'product_provider.dart';
import '../activation/auth_provider.dart';
import 'product_models.dart';

class ProductPage extends StatefulWidget {
  const ProductPage({super.key});

  @override
  State<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  Product? _selectedProductForTablet;
  bool _isEditingTablet = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(), // 返回收银台
        ),
        // ✨ 修复 2：恢复双击标题解除激活状态的调试后门
        title: GestureDetector(
          onDoubleTap: () {
            context.read<AuthProvider>().deactivateDevice();
            context.go('/activation');
          },
          child: const Text(
            '商品管理系统',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        // 删除了自作主张的“退出登录”IconButton
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 800) {
            return _buildTabletLayout();
          } else {
            return _buildMobileLayout();
          }
        },
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        _buildSearchBar(),
        Expanded(child: _buildProductList(isMobile: true)),
      ],
    );
  }

  Widget _buildTabletLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: Column(
            children: [
              _buildSearchBar(),
              Expanded(child: _buildProductList(isMobile: false)),
            ],
          ),
        ),
        const VerticalDivider(width: 1, color: Colors.grey),
        Expanded(
          flex: 3,
          child: Container(
            color: Colors.white,
            child: _isEditingTablet || _selectedProductForTablet != null
                ? ProductFormWidget(
                    product: _selectedProductForTablet,
                    onSaved: () {
                      setState(() {
                        _selectedProductForTablet = null;
                        _isEditingTablet = false;
                      });
                    },
                    onCancel: () {
                      setState(() {
                        _selectedProductForTablet = null;
                        _isEditingTablet = false;
                      });
                    },
                  )
                : const Center(
                    child: Text(
                      '请在左侧选择商品进行编辑，\n或点击左下角“新增商品”',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              onChanged: (val) =>
                  context.read<ProductProvider>().runFilter(val),
              decoration: InputDecoration(
                hintText: '搜索商品名称...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductList({required bool isMobile}) {
    return Consumer<ProductProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (provider.errorMessage != null) {
          return Center(
            child: Text(
              provider.errorMessage!,
              style: const TextStyle(color: Colors.red),
            ),
          );
        }
        if (provider.filteredProducts.isEmpty) {
          return const Center(child: Text('暂无商品'));
        }

        return Stack(
          children: [
            ListView.separated(
              padding: const EdgeInsets.only(bottom: 80, top: 8),
              itemCount: provider.filteredProducts.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final product = provider.filteredProducts[index];
                final bool isSelectedTablet =
                    !isMobile && _selectedProductForTablet?.id == product.id;

                // ✨ 修复 2：优雅的三色库存预警分层逻辑
                Color stockBgColor;
                Color stockBorderColor;
                Color stockTextColor;
                String stockText = '库存: ${product.stock}';

                if (product.stock <= 0) {
                  // 红档：售罄
                  stockBgColor = Colors.red.shade50;
                  stockBorderColor = Colors.red.shade300;
                  stockTextColor = Colors.red;
                  stockText = '售罄 (0)';
                } else if (product.stock <= 10) {
                  // 黄/橙档：库存紧张 (1-10)
                  stockBgColor = Colors.orange.shade50;
                  stockBorderColor = Colors.orange.shade400;
                  stockTextColor = Colors.orange.shade800;
                } else {
                  // 绿档：库存充裕 (>10)
                  stockBgColor = Colors.green.shade50;
                  stockBorderColor = Colors.green;
                  stockTextColor = Colors.green.shade700;
                }

                return ListTile(
                  tileColor: isSelectedTablet
                      ? Colors.blue.withOpacity(0.05)
                      : Colors.white,
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: product.imageUrl != null
                        ? Image.network(
                            product.imageUrl!,
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => _fallbackIcon(),
                          )
                        : _fallbackIcon(),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          product.name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            decoration: product.isActive
                                ? null
                                : TextDecoration.lineThrough,
                            color: product.isActive
                                ? Colors.black87
                                : Colors.grey,
                          ),
                        ),
                      ),
                      // ✨ 替换这里的角标 UI
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: stockBgColor,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: stockBorderColor),
                        ),
                        child: Text(
                          stockText,
                          style: TextStyle(
                            fontSize: 12,
                            color: stockTextColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Text(
                    '¥ ${product.price.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.orangeAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  // ✨ 修复 1：把上下架开关和删除按钮统一暴露，不再因平板模式隐藏
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(
                        value: product.isActive,
                        onChanged: (val) => provider.toggleProductStatus(
                          product.id,
                          product.isActive,
                          context,
                        ),
                      ),
                      if (isMobile)
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () =>
                              _showMobileBottomSheet(context, product),
                        ),
                      // 垃圾桶按钮：现在平板和手机都能看到，点击即可触发假删除防误触弹窗
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _confirmDelete(context, product),
                      ),
                      if (!isMobile)
                        const Icon(Icons.chevron_right, color: Colors.grey),
                    ],
                  ),
                  onTap: () {
                    if (isMobile) {
                      _showMobileBottomSheet(context, product);
                    } else {
                      setState(() {
                        _selectedProductForTablet = product;
                        _isEditingTablet = true;
                      });
                    }
                  },
                );
              },
            ),
            Positioned(
              bottom: 20,
              right: 20,
              child: FloatingActionButton.extended(
                onPressed: () {
                  if (isMobile) {
                    _showMobileBottomSheet(context, null);
                  } else {
                    setState(() {
                      _selectedProductForTablet = null;
                      _isEditingTablet = true;
                    });
                  }
                },
                icon: const Icon(Icons.add),
                label: const Text('新增商品'),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _fallbackIcon() => Container(
    width: 50,
    height: 50,
    color: Colors.grey[200],
    child: const Icon(Icons.fastfood, color: Colors.grey),
  );

  void _confirmDelete(BuildContext context, Product product) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red),
              SizedBox(width: 8),
              Text('删除确认'),
            ],
          ),
          content: Text('确定要永久下架并删除商品 [${product.name}] 吗？\n删除后将无法在此界面找回。'),
          actions: [
            TextButton(
              child: const Text('取消', style: TextStyle(color: Colors.grey)),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('确认删除', style: TextStyle(color: Colors.white)),
              onPressed: () {
                Navigator.of(ctx).pop();
                context.read<ProductProvider>().deleteProduct(
                  product.id,
                  product.name,
                  context,
                );
                if (_selectedProductForTablet?.id == product.id) {
                  setState(() {
                    _selectedProductForTablet = null;
                    _isEditingTablet = false;
                  });
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _showMobileBottomSheet(BuildContext context, Product? product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.75,
          child: ProductFormWidget(
            product: product,
            onSaved: () => Navigator.of(ctx).pop(),
            onCancel: () => Navigator.of(ctx).pop(),
          ),
        ),
      ),
    );
  }
}

class ProductFormWidget extends StatefulWidget {
  final Product? product;
  final VoidCallback onSaved;
  final VoidCallback onCancel;

  const ProductFormWidget({
    super.key,
    this.product,
    required this.onSaved,
    required this.onCancel,
  });

  @override
  State<ProductFormWidget> createState() => _ProductFormWidgetState();
}

class _ProductFormWidgetState extends State<ProductFormWidget> {
  late TextEditingController _nameCtrl;
  late TextEditingController _priceCtrl;
  late TextEditingController _stockCtrl;
  late TextEditingController _descCtrl;
  late bool _isActive;
  XFile? _selectedImage;
  final ImagePicker _picker = ImagePicker();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _initData();
  }

  @override
  void didUpdateWidget(covariant ProductFormWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.product?.id != widget.product?.id) {
      _initData();
    }
  }

  void _initData() {
    _nameCtrl = TextEditingController(text: widget.product?.name ?? '');
    _priceCtrl = TextEditingController(
      text: widget.product != null ? widget.product!.price.toString() : '',
    );
    _stockCtrl = TextEditingController(
      text: widget.product != null ? widget.product!.stock.toString() : '0',
    );
    _descCtrl = TextEditingController(text: widget.product?.description ?? '');
    _isActive = widget.product?.isActive ?? true;
    _selectedImage = null;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _stockCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (image != null) setState(() => _selectedImage = image);
  }

  // ✨ 修复 3：完全异步化的安全提交逻辑，绝不卡死
  // ✨ 终极优化：带 UX 拦截的安全提交逻辑
  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      final provider = context.read<ProductProvider>();
      final name = _nameCtrl.text.trim();
      final price = double.tryParse(_priceCtrl.text) ?? 0.0;
      final stock = int.tryParse(_stockCtrl.text) ?? 0;
      final desc = _descCtrl.text.trim();

      // ✨ 体验优化拦截：如果库存为 0 却强行要求上架，弹出友好提示
      if (stock <= 0 && _isActive) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange),
                SizedBox(width: 8),
                Text('库存与上架冲突'),
              ],
            ),
            content: const Text(
              '当前输入的库存为 0，系统为了防超卖，不允许零库存商品直接上架。\n\n您要自动将其【下架】并继续保存，还是返回修改库存？',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('返回修改', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text(
                  '自动下架并保存',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        );

        // 如果用户点击了“返回修改”或者点空白处关掉弹窗，直接中止提交过程
        if (proceed != true) return;

        // 如果用户同意，前端自动把状态纠正为 false，再发给后端
        setState(() {
          _isActive = false;
        });
      }

      // 走到这里说明校验全过，开始正式提交网络请求
      if (widget.product == null) {
        await provider.addProduct(
          name,
          price,
          stock,
          desc,
          _isActive,
          _selectedImage,
          context,
        );
      } else {
        await provider.updateProduct(
          widget.product!.id,
          name,
          price,
          stock,
          desc,
          _isActive,
          _selectedImage,
          context,
        );
      }

      // 只有在当前上下文还存活的情况下，才触发关闭表单的操作
      if (mounted) {
        widget.onSaved();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.product != null;
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isEditing ? ' ${widget.product!.name}' : '✨ 新增商品',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: widget.onCancel,
                  ),
                ],
              ),
              const Divider(height: 30),

              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: _selectedImage != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.file(
                              File(_selectedImage!.path),
                              fit: BoxFit.cover,
                            ),
                          )
                        : (isEditing && widget.product!.imageUrl != null)
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.network(
                              widget.product!.imageUrl!,
                              fit: BoxFit.cover,
                            ),
                          )
                        : const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_a_photo,
                                color: Colors.grey,
                                size: 30,
                              ),
                              SizedBox(height: 8),
                              Text(
                                '点击上传图片',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: '商品名称 *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.shopping_bag_outlined),
                ),
                validator: (val) =>
                    val == null || val.isEmpty ? '请输入商品名称' : null,
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _priceCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: '单价 (¥) *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.attach_money),
                      ),
                      validator: (val) =>
                          val == null || val.isEmpty ? '必填' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _stockCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '当前库存 *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.inventory_2_outlined),
                      ),
                      validator: (val) =>
                          val == null || val.isEmpty ? '必填' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _descCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: '商品描述',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),

              SwitchListTile(
                title: const Text(
                  '商品是否上架',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text('关闭后，收银台将无法搜索和购买此商品'),
                value: _isActive,
                activeThumbColor: Colors.blue,
                onChanged: (val) => setState(() => _isActive = val),
              ),

              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _submit,
                  child: Text(
                    isEditing ? '保存修改' : '确认新增',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
