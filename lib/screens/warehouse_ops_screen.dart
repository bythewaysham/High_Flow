import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/hiveflow_api.dart';
import '../theme/hiveflow_palette.dart';

enum _ScannerMethod { simulatedQr, cameraQr, barcode, rfid }

class WarehouseOpsScreen extends StatefulWidget {
  const WarehouseOpsScreen({required this.isActive, super.key});

  final bool isActive;

  @override
  State<WarehouseOpsScreen> createState() => _WarehouseOpsScreenState();
}

class _WarehouseOpsScreenState extends State<WarehouseOpsScreen> {
  late final TextEditingController _serverController;
  late HiveFlowApi _api;
  Map<String, dynamic> _summary = {};
  List<Map<String, dynamic>> _inventory = [];
  List<Map<String, dynamic>> _orders = [];
  List<Map<String, dynamic>> _robots = [];
  List<Map<String, dynamic>> _decisions = [];
  String? _error;
  String? _notice;
  bool _loading = false;
  bool _working = false;
  bool _connected = false;
  _ScannerMethod _scannerMethod = _ScannerMethod.simulatedQr;

  @override
  void initState() {
    super.initState();
    final server = HiveFlowApi.defaultBaseUrl();
    _serverController = TextEditingController(text: server);
    _api = HiveFlowApi(baseUrl: server);
    if (widget.isActive) _refresh();
  }

  @override
  void didUpdateWidget(covariant WarehouseOpsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive) unawaited(_refresh());
  }

  @override
  void dispose() {
    _serverController.dispose();
    _api.close();
    super.dispose();
  }

  Future<void> _refresh({bool announce = false}) async {
    setState(() {
      _loading = true;
      _error = null;
      if (announce) _notice = null;
    });
    try {
      final results = await Future.wait([
        _api.get('/summary'),
        _api.get('/inventory'),
        _api.get('/orders'),
        _api.get('/robots'),
        _api.get('/decisions'),
      ]);
      if (!mounted) return;
      setState(() {
        _summary = _object(results[0]['summary']);
        _inventory = _objects(results[1]['items']);
        _orders = _objects(results[2]['orders']);
        _robots = _objects(results[3]['robots']);
        _decisions = _objects(results[4]['decisions']);
        _loading = false;
        _working = false;
        _connected = true;
        _error = null;
      });
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _working = false;
        _connected = false;
        _error = _connectionMessage(error);
      });
    }
  }

  String _connectionMessage(Exception error) {
    final message = error.toString().replaceFirst('Exception: ', '');
    if (_serverController.text.trim().startsWith('http://10.0.2.2')) {
      return '10.0.2.2 only works in an Android emulator. On your real phone, enter your laptop Wi-Fi IP (Mac: ipconfig getifaddr en0), then tap Connect. Also make sure the backend is running on your laptop.';
    }
    if (_serverController.text.trim().isEmpty) {
      return 'Enter your laptop Wi-Fi IP first. On your Mac, run: ipconfig getifaddr en0. Then use http://<that-IP>:3000 and tap Connect.';
    }
    return '$message If this is a real phone, use your laptop Wi-Fi IP instead of localhost or 10.0.2.2.';
  }

  Future<void> _connectToServer() async {
    final address = _serverController.text.trim().replaceFirst(
      RegExp(r'/+$'),
      '',
    );
    if (address != _api.baseUrl) {
      _api.close();
      _api = HiveFlowApi(baseUrl: address);
    }
    await _refresh();
  }

  void _useEmulatorAddress() {
    _serverController.text = 'http://10.0.2.2:3000';
    unawaited(_connectToServer());
  }

  void _showConnectionHelp() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.wifi_tethering_rounded),
        title: const Text('Connect your phone to the laptop'),
        content: const SingleChildScrollView(
          child: SelectableText(
            '1. Keep the phone and Mac on the same Wi-Fi.\n'
            '   Your screenshot shows 5G; mobile data alone cannot reach your Mac’s local server.\n'
            '2. On the Mac, open Terminal and run: ipconfig getifaddr en0\n'
            '3. Start the API in another Terminal:\n'
            '   cd ~/Documents/Projects/HighFlow/highflow/backend\n'
            '   npm run dev\n'
            '4. In Backend address, enter http://<Mac-IP>:3000 '
            '(example: http://192.168.1.5:3000), then tap Connect.\n\n'
            '10.0.2.2 is only for the Android emulator. A real phone cannot use it.',
            style: TextStyle(height: 1.5),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Future<void> _createOrder() async {
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _CreateOrderDialog(products: _inventory),
    );
    if (payload == null || !mounted) return;
    await _perform(() async {
      final response = await _api.post('/orders', payload);
      final order = _object(response['order']);
      return 'Order ${order['id'] ?? ''} saved to PostgreSQL.';
    });
  }

  Future<void> _dispatchOrders() => _perform(() async {
    final result = await _api.post('/dispatch');
    final assignments = _objects(result['assignments']);
    if (assignments.isEmpty) return 'No queued orders or available robots.';
    final names = assignments
        .map((item) => '${item['robotId']} → ${item['orderId']}')
        .join(', ');
    return 'Assigned ${assignments.length} order(s): $names';
  });

  Future<void> _perform(Future<String> Function() action) async {
    setState(() {
      _working = true;
      _error = null;
      _notice = null;
    });
    try {
      final message = await action();
      if (!mounted) return;
      setState(() => _notice = message);
      await _refresh();
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _working = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _simulateScan(
    Map<String, dynamic> robot,
    String scanType,
  ) async {
    final orderId = robot['orderId']?.toString();
    final robotId = robot['id']?.toString();
    if (orderId == null || robotId == null) return;

    setState(() {
      _working = true;
      _error = null;
      _notice = null;
    });
    try {
      final response = await _api.get('/orders/$orderId');
      final order = _object(response['order']);
      final orderItems = _objects(order['items']).where((item) {
        final quantity = _integer(item['quantity']);
        final picked = _integer(item['pickedQuantity']);
        final delivered = _integer(item['deliveredQuantity']);
        return scanType == 'pick' ? picked < quantity : delivered < picked;
      }).toList();
      if (!mounted) return;
      setState(() => _working = false);
      if (orderItems.isEmpty) {
        setState(() {
          _notice = scanType == 'pick'
              ? 'All order items have already been picked.'
              : 'No picked items are waiting for delivery.';
        });
        return;
      }
      final item = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => _SimulatedScanDialog(
          robotId: robotId,
          orderId: orderId,
          scanType: scanType,
          items: orderItems,
        ),
      );
      if (item == null || !mounted) return;
      await _perform(() async {
        final result = await _api.post('/scans', {
          'eventId': HiveFlowApi.newEventId(),
          'robotId': robotId,
          'scanCode': item['scanCode'],
          'scanType': scanType,
          'metadata': {'source': 'hiveflow-app-simulator'},
        });
        final status = result['orderStatus'];
        return status == null
            ? 'Duplicate scan safely ignored.'
            : '${scanType == 'pick' ? 'Pick' : 'Delivery'} scan saved. Order is $status.';
      });
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _working = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _submitBarcode(Map<String, dynamic> robot, String code) async {
    final robotId = robot['id']?.toString();
    final orderId = robot['orderId']?.toString();
    if (robotId == null || orderId == null || code.trim().isEmpty) return;
    final scanType = robot['status'] == 'delivering' ? 'deliver' : 'pick';
    await _perform(() async {
      final result = await _api.post('/scans', {
        'eventId': HiveFlowApi.newEventId(),
        'robotId': robotId,
        'scanCode': code.trim(),
        'scanType': scanType,
        'metadata': {'source': 'hiveflow-barcode-input'},
      });
      final status = result['orderStatus'];
      return status == null
          ? 'Duplicate barcode event safely ignored.'
          : 'Barcode ${scanType == 'pick' ? 'pick' : 'delivery'} scan saved. Order is $status.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 720;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            compact ? 16 : 28,
            22,
            compact ? 16 : 28,
            36,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _header(compact),
                  const SizedBox(height: 18),
                  _connectionPanel(compact),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    _MessageBanner(message: _error!, isError: true),
                  ],
                  if (_notice != null) ...[
                    const SizedBox(height: 12),
                    _MessageBanner(message: _notice!, isError: false),
                  ],
                  const SizedBox(height: 18),
                  _scannerOptions(compact),
                  const SizedBox(height: 18),
                  if (_loading && _summary.isEmpty)
                    const _LoadingPanel()
                  else ...[
                    _summaryCards(compact),
                    const SizedBox(height: 18),
                    _actionRow(compact),
                    const SizedBox(height: 18),
                    _responsiveSections(compact),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _header(bool compact) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Warehouse operations',
              style: TextStyle(
                color: HiveFlowPalette.text,
                fontSize: compact ? 22 : 27,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Live orders, stock, robot assignments and simulated QR scans.',
              style: TextStyle(color: HiveFlowPalette.muted, fontSize: 12),
            ),
          ],
        ),
      ),
      const SizedBox(width: 8),
      IconButton.filledTonal(
        onPressed: _loading || _working ? null : () => _refresh(announce: true),
        tooltip: 'Refresh from backend',
        icon: const Icon(Icons.refresh_rounded),
      ),
    ],
  );

  Widget _connectionPanel(bool compact) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: HiveFlowPalette.surface,
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: HiveFlowPalette.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              _connected ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
              size: 17,
              color: _connected ? HiveFlowPalette.mint : HiveFlowPalette.amber,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _connected
                    ? 'PostgreSQL backend connected'
                    : _loading
                    ? 'Connecting to HiveFlow API…'
                    : _summary.isNotEmpty
                    ? 'Backend disconnected · showing last saved data'
                    : 'Backend not connected',
                style: TextStyle(
                  color: _connected
                      ? HiveFlowPalette.mint
                      : HiveFlowPalette.amber,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (_working)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        const SizedBox(height: 10),
        compact
            ? Column(
                children: [
                  _serverField(),
                  const SizedBox(height: 8),
                  _connectButton(),
                  const SizedBox(height: 4),
                  Wrap(
                    alignment: WrapAlignment.center,
                    children: [
                      TextButton.icon(
                        onPressed: _showConnectionHelp,
                        icon: const Icon(Icons.help_outline_rounded, size: 15),
                        label: const Text('Phone setup'),
                      ),
                      if (!kIsWeb &&
                          defaultTargetPlatform == TargetPlatform.android)
                        TextButton(
                          onPressed: _useEmulatorAddress,
                          child: const Text('Android emulator'),
                        ),
                    ],
                  ),
                ],
              )
            : Row(
                children: [
                  Expanded(child: _serverField()),
                  const SizedBox(width: 9),
                  _connectButton(),
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: _showConnectionHelp,
                    tooltip: 'Phone setup instructions',
                    icon: const Icon(Icons.help_outline_rounded),
                  ),
                ],
              ),
        const SizedBox(height: 8),
        const Text(
          'Laptop: localhost works. Android emulator: 10.0.2.2. Physical phone: enter your laptop’s Wi-Fi IP.',
          style: TextStyle(
            color: HiveFlowPalette.subtle,
            fontSize: 10,
            height: 1.4,
          ),
        ),
      ],
    ),
  );

  Widget _serverField() => TextField(
    controller: _serverController,
    keyboardType: TextInputType.url,
    style: const TextStyle(color: HiveFlowPalette.text, fontSize: 12),
    decoration: const InputDecoration(
      labelText: 'Backend address',
      hintText: 'Phone: http://<laptop-wifi-IP>:3000',
      prefixIcon: Icon(Icons.link_rounded, size: 18),
      isDense: true,
    ),
    onSubmitted: (_) => _connectToServer(),
  );

  Widget _connectButton() => FilledButton.tonal(
    onPressed: _loading || _working ? null : _connectToServer,
    child: const Text('Connect'),
  );

  Widget _scannerOptions(bool compact) => _OpsPanel(
    title: 'Scanner options',
    subtitle: 'Hardware-free QR simulation is selected for this demo',
    icon: Icons.qr_code_scanner_rounded,
    child: Column(
      children: [
        _ScannerOptionTile(
          title: 'QR label + simulated robot scans',
          description: 'Recommended · hardware-free demo',
          selected: _scannerMethod == _ScannerMethod.simulatedQr,
          available: true,
          onTap: () =>
              setState(() => _scannerMethod = _ScannerMethod.simulatedQr),
        ),
        _ScannerOptionTile(
          title: 'QR label + live phone camera scanning',
          description: 'Planned · camera scanning is not connected yet',
          selected: _scannerMethod == _ScannerMethod.cameraQr,
          available: false,
          onTap: () => setState(() => _scannerMethod = _ScannerMethod.cameraQr),
        ),
        _ScannerOptionTile(
          title: 'Barcode scanner input',
          description:
              'Available · type a code or use a Bluetooth/USB keyboard scanner',
          selected: _scannerMethod == _ScannerMethod.barcode,
          available: true,
          onTap: () => setState(() => _scannerMethod = _ScannerMethod.barcode),
        ),
        _ScannerOptionTile(
          title: 'RFID reader integration',
          description: 'Planned · requires an RFID reader and vendor adapter',
          selected: _scannerMethod == _ScannerMethod.rfid,
          available: false,
          onTap: () => setState(() => _scannerMethod = _ScannerMethod.rfid),
        ),
        if (_scannerMethod == _ScannerMethod.cameraQr ||
            _scannerMethod == _ScannerMethod.rfid)
          const _MessageBanner(
            message: 'This connection type is shown for the roadmap, but is not built yet. Choose simulated QR or barcode input for the demo.',
            isError: false,
          ),
        if (_scannerMethod == _ScannerMethod.barcode) ...[
          const SizedBox(height: 8),
          _BarcodeInput(
            robots: _robots
                .where(
                  (robot) =>
                      robot['orderId'] != null &&
                      [
                        'assigned',
                        'picking',
                        'delivering',
                      ].contains(robot['status']),
                )
                .toList(),
            enabled: _connected && !_working,
            onSubmit: _submitBarcode,
          ),
          if (!_connected)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Connect to the backend before submitting scanner input.',
                style: TextStyle(color: HiveFlowPalette.amber, fontSize: 10),
              ),
            ),
        ],
      ],
    ),
  );

  Widget _summaryCards(bool compact) {
    final values = [
      (
        'Orders',
        _connected ? _summary['totalOrders'] ?? 0 : '—',
        Icons.inventory_2_outlined,
        HiveFlowPalette.blue,
      ),
      (
        'Queued',
        _connected ? _summary['queuedOrders'] ?? 0 : '—',
        Icons.hourglass_bottom_rounded,
        HiveFlowPalette.amber,
      ),
      (
        'Robots online',
        _connected ? _summary['onlineRobots'] ?? 0 : '—',
        Icons.smart_toy_outlined,
        HiveFlowPalette.mint,
      ),
      (
        'Stock units',
        _connected ? _summary['inventoryUnits'] ?? 0 : '—',
        Icons.widgets_outlined,
        HiveFlowPalette.violet,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = compact ? 2 : 4;
        final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final item in values)
              SizedBox(
                width: width,
                child: _MetricCard(
                  label: item.$1,
                  value: item.$2.toString(),
                  icon: item.$3,
                  color: item.$4,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _actionRow(bool compact) {
    final buttons = [
      FilledButton.icon(
        onPressed: !_connected || _working || _loading ? null : _createOrder,
        icon: const Icon(Icons.add_shopping_cart_rounded, size: 17),
        label: const Text('Create order'),
      ),
      OutlinedButton.icon(
        onPressed: !_connected || _working || _loading ? null : _dispatchOrders,
        icon: const Icon(Icons.route_rounded, size: 17),
        label: const Text('Assign queued orders'),
      ),
    ];
    return compact
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [buttons[0], const SizedBox(height: 8), buttons[1]],
          )
        : Row(
            children: [
              buttons[0],
              const SizedBox(width: 10),
              buttons[1],
              const Spacer(),
              Text(
                '${_connected ? _summary['scanEvents'] ?? 0 : '—'} recorded scan events',
                style: const TextStyle(
                  color: HiveFlowPalette.muted,
                  fontSize: 11,
                ),
              ),
            ],
          );
  }

  Widget _responsiveSections(bool compact) {
    if (compact) {
      return Column(
        children: [
          _ordersSection(),
          const SizedBox(height: 14),
          _robotsSection(),
          const SizedBox(height: 14),
          _inventorySection(),
          const SizedBox(height: 14),
          _decisionsSection(),
        ],
      );
    }
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 6, child: _ordersSection()),
            const SizedBox(width: 14),
            Expanded(flex: 4, child: _robotsSection()),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _inventorySection()),
            const SizedBox(width: 14),
            Expanded(child: _decisionsSection()),
          ],
        ),
      ],
    );
  }

  Widget _ordersSection() => _OpsPanel(
    title: 'Recent orders',
    subtitle: 'Persisted in the warehouse database',
    icon: Icons.receipt_long_rounded,
    child: _orders.isEmpty
        ? const _EmptyHint('No orders yet. Create a test order to get started.')
        : Column(
            children: [
              for (final order in _orders.take(12)) _OrderRow(order: order),
            ],
          ),
  );

  Widget _robotsSection() => _OpsPanel(
    title: 'Robot assignments',
    subtitle: 'Generic adapter IDs · no vendor locked in',
    icon: Icons.smart_toy_outlined,
    child: _robots.isEmpty
        ? const _EmptyHint('The API returned no robots.')
        : Column(
            children: [
              for (final robot in _robots)
                _RobotRow(
                  robot: robot,
                  onScan:
                      _working || _scannerMethod != _ScannerMethod.simulatedQr
                      ? null
                      : (type) => _simulateScan(robot, type),
                ),
            ],
          ),
  );

  Widget _inventorySection() => _OpsPanel(
    title: 'Inventory & QR labels',
    subtitle: 'Simulated scanner uses these product scan codes',
    icon: Icons.qr_code_2_rounded,
    child: _inventory.isEmpty
        ? const _EmptyHint('No catalog items found.')
        : Column(
            children: [
              for (final item in _inventory) _InventoryRow(item: item),
            ],
          ),
  );

  Widget _decisionsSection() => _OpsPanel(
    title: 'Backend activity',
    subtitle: 'Assignments and scan history from the decision log',
    icon: Icons.fact_check_outlined,
    child: _decisions.isEmpty
        ? const _EmptyHint('No backend decisions have been recorded yet.')
        : Column(
            children: [
              for (final decision in _decisions.take(10))
                _DecisionRow(decision: decision),
            ],
          ),
  );
}

class _CreateOrderDialog extends StatefulWidget {
  const _CreateOrderDialog({required this.products});

  final List<Map<String, dynamic>> products;

  @override
  State<_CreateOrderDialog> createState() => _CreateOrderDialogState();
}

class _CreateOrderDialogState extends State<_CreateOrderDialog> {
  final _customer = TextEditingController();
  final _quantity = TextEditingController(text: '1');
  final List<Map<String, dynamic>> _lines = [];
  String? _selectedSku;
  String _priority = 'normal';

  @override
  void initState() {
    super.initState();
    if (widget.products.isNotEmpty) {
      _selectedSku = widget.products.first['sku']?.toString();
    }
  }

  @override
  void dispose() {
    _customer.dispose();
    _quantity.dispose();
    super.dispose();
  }

  void _addLine() {
    final quantity = int.tryParse(_quantity.text.trim());
    if (_selectedSku == null || quantity == null || quantity < 1) return;
    if (_lines.any((line) => line['sku'] == _selectedSku)) return;
    setState(() {
      _lines.add({'sku': _selectedSku, 'quantity': quantity});
      final availableSkus = widget.products
          .map((item) => item['sku']?.toString())
          .whereType<String>()
          .where((sku) => !_lines.any((line) => line['sku'] == sku))
          .toList();
      _selectedSku = availableSkus.isEmpty ? null : availableSkus.first;
      _quantity.text = '1';
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Create warehouse order'),
    content: SizedBox(
      width: 480,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _customer,
              decoration: const InputDecoration(
                labelText: 'Customer / reference (optional)',
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _selectedSku,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Product'),
              items: [
                for (final product in widget.products)
                  if (!_lines.any((line) => line['sku'] == product['sku']))
                    DropdownMenuItem(
                      value: product['sku'].toString(),
                      child: Text(
                        '${product['name']} · ${product['onHand']} in stock',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
              ],
              onChanged: (value) => setState(() => _selectedSku = value),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _quantity,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Quantity'),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filledTonal(
                  onPressed: _addLine,
                  tooltip: 'Add product to order',
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
            if (_lines.isNotEmpty) ...[
              const SizedBox(height: 12),
              for (final line in _lines)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(line['sku'].toString()),
                  subtitle: Text('Quantity ${line['quantity']}'),
                  trailing: IconButton(
                    onPressed: () => setState(() {
                      _lines.remove(line);
                      _selectedSku ??= line['sku'].toString();
                    }),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ),
            ],
            const SizedBox(height: 12),
            const Text(
              'Priority',
              style: TextStyle(color: HiveFlowPalette.muted, fontSize: 12),
            ),
            const SizedBox(height: 6),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'normal', label: Text('Normal')),
                ButtonSegment(value: 'rush', label: Text('Rush')),
              ],
              selected: {_priority},
              onSelectionChanged: (value) =>
                  setState(() => _priority = value.first),
            ),
            if (_lines.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text(
                  'Add at least one product to create this order.',
                  style: TextStyle(color: HiveFlowPalette.amber, fontSize: 11),
                ),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _lines.isEmpty
            ? null
            : () => Navigator.pop(context, {
                if (_customer.text.trim().isNotEmpty)
                  'customerRef': _customer.text.trim(),
                'priority': _priority,
                'items': _lines,
              }),
        child: const Text('Save order'),
      ),
    ],
  );
}

class _SimulatedScanDialog extends StatelessWidget {
  const _SimulatedScanDialog({
    required this.robotId,
    required this.orderId,
    required this.scanType,
    required this.items,
  });

  final String robotId;
  final String orderId;
  final String scanType;
  final List<Map<String, dynamic>> items;

  @override
  Widget build(BuildContext context) => AlertDialog(
    icon: const Icon(
      Icons.qr_code_scanner_rounded,
      color: HiveFlowPalette.lime,
    ),
    title: Text(
      scanType == 'pick' ? 'Simulate item pick' : 'Simulate delivery',
    ),
    content: SizedBox(
      width: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$robotId · $orderId',
            style: const TextStyle(color: HiveFlowPalette.muted, fontSize: 12),
          ),
          const SizedBox(height: 8),
          const Text(
            'Hardware-free demo · choose a QR label to record a simulated scan. No camera is used.',
            style: TextStyle(color: HiveFlowPalette.subtle, fontSize: 11),
          ),
          const SizedBox(height: 12),
          for (final item in items)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.qr_code_2_rounded),
              title: Text(item['name']?.toString() ?? item['sku'].toString()),
              subtitle: Text(
                '${item['scanCode']}  ·  ${scanType == 'pick' ? 'picked' : 'delivered'} '
                '${scanType == 'pick' ? item['pickedQuantity'] : item['deliveredQuantity']} / ${item['quantity']}',
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.pop(context, item),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
    ],
  );
}

class _ScannerOptionTile extends StatelessWidget {
  const _ScannerOptionTile({
    required this.title,
    required this.description,
    required this.selected,
    required this.available,
    required this.onTap,
  });

  final String title;
  final String description;
  final bool selected;
  final bool available;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = selected ? HiveFlowPalette.lime : HiveFlowPalette.muted;
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Material(
        color: selected
            ? HiveFlowPalette.lime.withValues(alpha: 0.08)
            : HiveFlowPalette.surfaceInset,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 19,
                  color: accent,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: selected
                              ? HiveFlowPalette.text
                              : HiveFlowPalette.muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        description,
                        style: const TextStyle(
                          color: HiveFlowPalette.subtle,
                          fontSize: 9,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 7),
                _StatusPill(status: available ? 'available' : 'planned'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BarcodeInput extends StatefulWidget {
  const _BarcodeInput({
    required this.robots,
    required this.enabled,
    required this.onSubmit,
  });

  final List<Map<String, dynamic>> robots;
  final bool enabled;
  final Future<void> Function(Map<String, dynamic> robot, String code) onSubmit;

  @override
  State<_BarcodeInput> createState() => _BarcodeInputState();
}

class _BarcodeInputState extends State<_BarcodeInput> {
  final _codeController = TextEditingController();
  String? _robotId;

  @override
  void didUpdateWidget(covariant _BarcodeInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.robots.any((robot) => robot['id'] == _robotId)) {
      _robotId = widget.robots.isEmpty
          ? null
          : widget.robots.first['id']?.toString();
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _codeController.text.trim();
    final matches = widget.robots.where(
      (robot) => robot['id']?.toString() == _robotId,
    );
    if (!widget.enabled || code.isEmpty || matches.isEmpty) return;
    await widget.onSubmit(matches.first, code);
    if (mounted) _codeController.clear();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.robots.isEmpty) {
      return const _EmptyHint(
        'Dispatch an order to a robot, then enter or scan its product barcode.',
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 460;
        final robotPicker = DropdownButtonFormField<String>(
          initialValue: _robotId,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Assigned robot',
            isDense: true,
          ),
          items: [
            for (final robot in widget.robots)
              DropdownMenuItem(
                value: robot['id'].toString(),
                child: Text('${robot['id']} · ${robot['orderId']}'),
              ),
          ],
          onChanged: widget.enabled
              ? (value) => setState(() => _robotId = value)
              : null,
        );
        final scannerField = TextField(
          controller: _codeController,
          enabled: widget.enabled,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            labelText: 'Scan code',
            hintText: 'e.g. HF-BOLT-001 · scanner sends Enter',
            prefixIcon: const Icon(Icons.document_scanner_rounded, size: 18),
            suffixIcon: IconButton(
              onPressed: widget.enabled ? _submit : null,
              tooltip: 'Submit scan',
              icon: const Icon(Icons.send_rounded, size: 17),
            ),
            isDense: true,
          ),
        );
        return compact
            ? Column(
                children: [
                  robotPicker,
                  const SizedBox(height: 8),
                  scannerField,
                ],
              )
            : Row(
                children: [
                  SizedBox(width: 210, child: robotPicker),
                  const SizedBox(width: 9),
                  Expanded(child: scannerField),
                ],
              );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: HiveFlowPalette.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: HiveFlowPalette.border),
    ),
    child: Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: HiveFlowPalette.text,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: HiveFlowPalette.muted,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _OpsPanel extends StatelessWidget {
  const _OpsPanel({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: HiveFlowPalette.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: HiveFlowPalette.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 17, color: HiveFlowPalette.lime),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: HiveFlowPalette.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(color: HiveFlowPalette.subtle, fontSize: 10),
        ),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );
}

class _OrderRow extends StatelessWidget {
  const _OrderRow({required this.order});

  final Map<String, dynamic> order;

  @override
  Widget build(BuildContext context) {
    final items = _objects(order['items']);
    final status = order['status']?.toString() ?? 'unknown';
    final progress = items.fold<int>(
      0,
      (total, item) => total + _integer(item['deliveredQuantity']),
    );
    final target = items.fold<int>(
      0,
      (total, item) => total + _integer(item['quantity']),
    );
    return _RowDivider(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    order['id']?.toString() ?? 'Order',
                    style: const TextStyle(
                      color: HiveFlowPalette.text,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _StatusPill(status: status),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              '${order['customerRef'] ?? 'Walk-in order'}  ·  ${order['priority'] ?? 'normal'} priority',
              style: const TextStyle(
                color: HiveFlowPalette.muted,
                fontSize: 10,
              ),
            ),
            if (items.isNotEmpty) ...[
              const SizedBox(height: 5),
              Text(
                '${items.map((item) => '${item['name']} ×${item['quantity']}').join(' · ')}  ·  delivered $progress/$target',
                style: const TextStyle(
                  color: HiveFlowPalette.subtle,
                  fontSize: 10,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RobotRow extends StatelessWidget {
  const _RobotRow({required this.robot, required this.onScan});

  final Map<String, dynamic> robot;
  final ValueChanged<String>? onScan;

  @override
  Widget build(BuildContext context) {
    final status = robot['status']?.toString() ?? 'unknown';
    final activeTask = robot['taskId'] != null && robot['orderId'] != null;
    return _RowDivider(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.smart_toy_rounded,
                  color: HiveFlowPalette.mint,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    robot['id']?.toString() ?? 'Robot',
                    style: const TextStyle(
                      color: HiveFlowPalette.text,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _StatusPill(status: status),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              'Battery ${robot['battery'] ?? '—'}%  ·  '
              'Position ${_point(robot['position'])}  ·  '
              'Order ${robot['orderId'] ?? 'unassigned'}',
              style: const TextStyle(
                color: HiveFlowPalette.muted,
                fontSize: 10,
              ),
            ),
            if (activeTask &&
                (status == 'assigned' ||
                    status == 'picking' ||
                    status == 'delivering')) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 7,
                runSpacing: 6,
                children: [
                  if (status != 'delivering')
                    OutlinedButton.icon(
                      onPressed: onScan == null ? null : () => onScan!('pick'),
                      icon: const Icon(Icons.qr_code_scanner_rounded, size: 14),
                      label: const Text('Simulate pick'),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        textStyle: const TextStyle(fontSize: 10),
                      ),
                    ),
                  if (status == 'delivering')
                    OutlinedButton.icon(
                      onPressed: onScan == null
                          ? null
                          : () => onScan!('deliver'),
                      icon: const Icon(Icons.qr_code_scanner_rounded, size: 14),
                      label: const Text('Simulate delivery scan'),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        textStyle: const TextStyle(fontSize: 10),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InventoryRow extends StatelessWidget {
  const _InventoryRow({required this.item});

  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) => _RowDivider(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          const Icon(
            Icons.inventory_2_outlined,
            size: 17,
            color: HiveFlowPalette.blue,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['name']?.toString() ?? item['sku'].toString(),
                  style: const TextStyle(
                    color: HiveFlowPalette.text,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${item['sku']}  ·  QR ${item['scanCode']}  ·  bin ${_point(item['bin'])}',
                  style: const TextStyle(
                    color: HiveFlowPalette.muted,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '${item['onHand']}',
            style: const TextStyle(
              color: HiveFlowPalette.lime,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    ),
  );
}

class _DecisionRow extends StatelessWidget {
  const _DecisionRow({required this.decision});

  final Map<String, dynamic> decision;

  @override
  Widget build(BuildContext context) => _RowDivider(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.bolt_rounded,
            size: 16,
            color: HiveFlowPalette.amber,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  decision['message']?.toString() ??
                      decision['type'].toString(),
                  style: const TextStyle(
                    color: HiveFlowPalette.text,
                    fontSize: 10,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${decision['type']}  ·  Robot ${decision['robotId'] ?? '—'}  ·  ${_formatTime(decision['createdAt'])}',
                  style: const TextStyle(
                    color: HiveFlowPalette.subtle,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'completed' || 'idle' || 'delivering' => HiveFlowPalette.mint,
      'picking' ||
      'assigned' ||
      'queued' ||
      'received' => HiveFlowPalette.amber,
      'cancelled' || 'unavailable' => HiveFlowPalette.red,
      _ => HiveFlowPalette.blue,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.35,
        ),
      ),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      child,
      const Divider(height: 1, color: HiveFlowPalette.border),
    ],
  );
}

class _MessageBanner extends StatelessWidget {
  const _MessageBanner({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError ? HiveFlowPalette.red : HiveFlowPalette.mint;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError
                ? Icons.error_outline_rounded
                : Icons.check_circle_outline_rounded,
            size: 17,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: color, fontSize: 11, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel();

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(36),
    decoration: BoxDecoration(
      color: HiveFlowPalette.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: HiveFlowPalette.border),
    ),
    child: const Column(
      children: [
        CircularProgressIndicator(),
        SizedBox(height: 13),
        Text(
          'Loading warehouse data from the backend…',
          style: TextStyle(color: HiveFlowPalette.muted, fontSize: 12),
        ),
      ],
    ),
  );
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 14),
    child: Text(
      text,
      style: const TextStyle(color: HiveFlowPalette.subtle, fontSize: 11),
    ),
  );
}

Map<String, dynamic> _object(dynamic value) =>
    value is Map<String, dynamic> ? value : <String, dynamic>{};

List<Map<String, dynamic>> _objects(dynamic value) {
  if (value is! List) return [];
  return value.whereType<Map<String, dynamic>>().toList();
}

int _integer(dynamic value) =>
    value is int ? value : int.tryParse('$value') ?? 0;

String _point(dynamic value) {
  final point = _object(value);
  final x = point['x'] ?? '—';
  final y = point['y'] ?? '—';
  return '($x, $y)';
}

String _formatTime(dynamic value) {
  if (value is! String) return '—';
  final date = DateTime.tryParse(value);
  if (date == null) return value;
  final local = date.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
