import 'package:flutter/material.dart';

import '../demo/hiveflow_demo.dart';
import 'warehouse_ops_screen.dart';
import '../theme/hiveflow_palette.dart';
import '../widgets/warehouse_map.dart';

class HiveFlowHome extends StatefulWidget {
  const HiveFlowHome({required this.controller, super.key});

  final HiveFlowDemoController controller;

  @override
  State<HiveFlowHome> createState() => _HiveFlowHomeState();
}

class _HiveFlowHomeState extends State<HiveFlowHome> {
  @override
  void dispose() {
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 1000;
            return Scaffold(
              body: SafeArea(
                child: Row(
                  children: [
                    if (!isMobile)
                      _SideNavigation(
                        activeTab: widget.controller.activeTab,
                        onSelect: widget.controller.setTab,
                      ),
                    Expanded(
                      child: DashboardScreen(
                        controller: widget.controller,
                        isMobile: isMobile,
                      ),
                    ),
                  ],
                ),
              ),
              bottomNavigationBar: isMobile
                  ? _MobileNavigation(
                      activeTab: widget.controller.activeTab,
                      onSelect: widget.controller.setTab,
                    )
                  : null,
            );
          },
        );
      },
    );
  }
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    required this.controller,
    required this.isMobile,
    super.key,
  });

  final HiveFlowDemoController controller;
  final bool isMobile;

  static const _navItems = [
    ('Overview', Icons.space_dashboard_rounded),
    ('Simulation', Icons.play_circle_outline_rounded),
    ('Fleet', Icons.smart_toy_outlined),
    ('Decisions', Icons.receipt_long_outlined),
    ('Warehouse Ops', Icons.inventory_2_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final title = _navItems[controller.activeTab].$1;
    return Column(
      children: [
        _TopBar(
          title: title,
          isMobile: isMobile,
          lastEvent: controller.lastEvent,
        ),
        Expanded(
          child: IndexedStack(
            index: controller.activeTab,
            children: [
              _OverviewPage(controller: controller, isMobile: isMobile),
              _SimulationPage(controller: controller, isMobile: isMobile),
              _FleetPage(controller: controller, isMobile: isMobile),
              _DecisionsPage(controller: controller, isMobile: isMobile),
              WarehouseOpsScreen(isActive: controller.activeTab == 4),
            ],
          ),
        ),
      ],
    );
  }
}

class _SideNavigation extends StatelessWidget {
  const _SideNavigation({required this.activeTab, required this.onSelect});

  final int activeTab;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 244,
      color: HiveFlowPalette.sidebar,
      padding: const EdgeInsets.fromLTRB(18, 22, 14, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _BrandLockup(),
          const SizedBox(height: 40),
          const _SmallLabel('WORKSPACE'),
          const SizedBox(height: 12),
          _NavButton(
            icon: Icons.space_dashboard_rounded,
            label: 'Overview',
            selected: activeTab == 0,
            onTap: () => onSelect(0),
          ),
          _NavButton(
            icon: Icons.play_circle_outline_rounded,
            label: 'Simulation',
            selected: activeTab == 1,
            onTap: () => onSelect(1),
          ),
          _NavButton(
            icon: Icons.smart_toy_outlined,
            label: 'Robot fleet',
            selected: activeTab == 2,
            onTap: () => onSelect(2),
          ),
          _NavButton(
            icon: Icons.receipt_long_outlined,
            label: 'Decision log',
            selected: activeTab == 3,
            onTap: () => onSelect(3),
          ),
          _NavButton(
            icon: Icons.inventory_2_outlined,
            label: 'Warehouse Ops',
            selected: activeTab == 4,
            onTap: () => onSelect(4),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.circle, size: 8, color: HiveFlowPalette.lime),
                    SizedBox(width: 8),
                    Text(
                      'SIM + LIVE OPS',
                      style: TextStyle(
                        color: HiveFlowPalette.lime,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 9),
                Text(
                  'The simulator uses sample data. Warehouse Ops reads from the backend.',
                  style: TextStyle(
                    color: HiveFlowPalette.muted,
                    fontSize: 11,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: HiveFlowPalette.lime,
                child: Text(
                  'CB',
                  style: TextStyle(
                    color: HiveFlowPalette.sidebar,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Team Code Breakers',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'IILM University',
                      style: TextStyle(
                        color: HiveFlowPalette.muted,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BrandLockup extends StatelessWidget {
  const _BrandLockup();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: Image.asset(
            'assets/logo/hiveflow_mark.png',
            width: 43,
            height: 43,
            fit: BoxFit.cover,
            semanticLabel: 'HiveFlow robotics software logo',
          ),
        ),
        const SizedBox(width: 11),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'HiveFlow',
              style: TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'FLEET COMMAND',
              style: TextStyle(
                color: HiveFlowPalette.muted,
                fontSize: 8,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Material(
        color: selected ? HiveFlowPalette.lime : Colors.transparent,
        borderRadius: BorderRadius.circular(11),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(11),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 19,
                  color: selected
                      ? HiveFlowPalette.sidebar
                      : HiveFlowPalette.muted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected
                          ? HiveFlowPalette.sidebar
                          : HiveFlowPalette.muted,
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                if (selected) ...[
                  const Spacer(),
                  Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      color: HiveFlowPalette.sidebar,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MobileNavigation extends StatelessWidget {
  const _MobileNavigation({required this.activeTab, required this.onSelect});

  final int activeTab;
  final ValueChanged<int> onSelect;

  static const _items = [
    (Icons.space_dashboard_rounded, 'Home'),
    (Icons.play_circle_outline_rounded, 'Demo'),
    (Icons.smart_toy_outlined, 'Fleet'),
    (Icons.receipt_long_outlined, 'Log'),
    (Icons.inventory_2_outlined, 'Ops'),
  ];

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: activeTab,
      onDestinationSelected: onSelect,
      backgroundColor: HiveFlowPalette.sidebar,
      indicatorColor: HiveFlowPalette.lime,
      destinations: [
        for (final item in _items)
          NavigationDestination(icon: Icon(item.$1), label: item.$2),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.isMobile,
    required this.lastEvent,
  });

  final String title;
  final bool isMobile;
  final String lastEvent;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 69,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 18 : 30),
      decoration: const BoxDecoration(
        color: HiveFlowPalette.surface,
        border: Border(bottom: BorderSide(color: HiveFlowPalette.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: HiveFlowPalette.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (!isMobile)
                  const Padding(
                    padding: EdgeInsets.only(top: 3),
                    child: Text(
                      'Warehouse 01  /  Main fulfillment center',
                      style: TextStyle(
                        color: HiveFlowPalette.muted,
                        fontSize: 11,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (!isMobile) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: HiveFlowPalette.surfaceRaised,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: HiveFlowPalette.border),
              ),
              child: const Row(
                children: [
                  Icon(Icons.circle, size: 7, color: HiveFlowPalette.amber),
                  SizedBox(width: 6),
                  Text(
                    'LOCAL PREVIEW',
                    style: TextStyle(
                      color: HiveFlowPalette.amber,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.7,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 17),
            Tooltip(
              message: lastEvent,
              child: const Icon(
                Icons.notifications_none_rounded,
                color: HiveFlowPalette.muted,
                size: 22,
              ),
            ),
            const SizedBox(width: 16),
          ],
          if (isMobile)
            ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: Image.asset(
                'assets/logo/hiveflow_mark.png',
                width: 34,
                height: 34,
                fit: BoxFit.cover,
                semanticLabel: 'HiveFlow robotics software logo',
              ),
            )
          else
            const CircleAvatar(
              radius: 16,
              backgroundColor: HiveFlowPalette.surfaceRaised,
              child: Text(
                'CB',
                style: TextStyle(
                  color: HiveFlowPalette.lime,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _OverviewPage extends StatelessWidget {
  const _OverviewPage({required this.controller, required this.isMobile});

  final HiveFlowDemoController controller;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    return _PageScroll(
      isMobile: isMobile,
      children: [
        _HeroBanner(controller: controller, isMobile: isMobile),
        const SizedBox(height: 18),
        _ClaimChips(isMobile: isMobile),
        const SizedBox(height: 22),
        _KpiGrid(controller: controller, isMobile: isMobile),
        const SizedBox(height: 21),
        _ResponsiveRow(
          isMobile: isMobile,
          leftFlex: 7,
          rightFlex: 3,
          left: _MapCard(controller: controller, height: 356),
          right: Column(
            children: [
              _FleetHealthCard(controller: controller),
              const SizedBox(height: 15),
              _DecisionCard(
                decisions: controller.decisions.take(3).toList(),
                compact: true,
                onViewAll: () => controller.setTab(3),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _ScenarioStrip(controller: controller, isMobile: isMobile),
        const SizedBox(height: 10),
        const _HonestyNote(),
      ],
    );
  }
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({required this.controller, required this.isMobile});

  final HiveFlowDemoController controller;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final headline = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 7,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                color: HiveFlowPalette.lime.withValues(alpha: 0.1),
                border: Border.all(
                  color: HiveFlowPalette.lime.withValues(alpha: 0.25),
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'AURIX HACKATHON 2026  /  TRACK 03',
                style: TextStyle(
                  color: HiveFlowPalette.lime,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.9,
                ),
              ),
            ),
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, size: 7, color: HiveFlowPalette.mint),
                SizedBox(width: 6),
                Text(
                  'LOCAL SIMULATION',
                  style: TextStyle(
                    color: HiveFlowPalette.muted,
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text.rich(
          TextSpan(
            style: TextStyle(
              color: HiveFlowPalette.text,
              fontSize: isMobile ? 28 : 36,
              height: 1.08,
              letterSpacing: -1.3,
              fontWeight: FontWeight.w800,
            ),
            children: const [
              TextSpan(text: 'The brain behind a\n'),
              TextSpan(
                text: 'better-moving warehouse.',
                style: TextStyle(color: HiveFlowPalette.lime),
              ),
            ],
          ),
        ),
        const SizedBox(height: 9),
        const Text(
          'One coordination layer for every robot. Assign smarter, route safely, recover locally.',
          style: TextStyle(
            color: HiveFlowPalette.muted,
            fontSize: 12,
            height: 1.55,
          ),
        ),
      ],
    );

    return Container(
      clipBehavior: Clip.antiAlias,
      padding: EdgeInsets.all(isMobile ? 17 : 23),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF162438), Color(0xFF122635), Color(0xFF132D2C)],
        ),
        border: Border.all(color: const Color(0xFF2A4151)),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: HiveFlowPalette.mint.withValues(alpha: 0.06),
            blurRadius: 28,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: isMobile ? -72 : 54,
            top: isMobile ? -104 : -110,
            child: Container(
              width: isMobile ? 170 : 255,
              height: isMobile ? 170 : 255,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: HiveFlowPalette.mint.withValues(alpha: 0.09),
                  width: 1.2,
                ),
              ),
              child: Center(
                child: Container(
                  width: isMobile ? 115 : 177,
                  height: isMobile ? 115 : 177,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: HiveFlowPalette.lime.withValues(alpha: 0.09),
                      width: 1,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (!isMobile)
            Positioned(
              right: 116,
              top: 41,
              child: Opacity(
                opacity: 0.22,
                child: Image.asset(
                  'assets/logo/hiveflow_mark.png',
                  width: 76,
                  height: 76,
                  fit: BoxFit.cover,
                  semanticLabel: 'HiveFlow logo',
                ),
              ),
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isMobile)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: headline),
                    const SizedBox(width: 16),
                    _RunControls(controller: controller, compact: false),
                  ],
                )
              else ...[
                headline,
                const SizedBox(height: 16),
                _RunControls(controller: controller, compact: true),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _PageHeading extends StatelessWidget {
  const _PageHeading({
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.isMobile,
    this.trailing,
  });

  final String eyebrow;
  final String title;
  final String description;
  final bool isMobile;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow,
          style: const TextStyle(
            color: HiveFlowPalette.mint,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.35,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: TextStyle(
            color: HiveFlowPalette.text,
            fontSize: isMobile ? 28 : 33,
            height: 1.1,
            letterSpacing: -1.2,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          description,
          style: const TextStyle(
            color: HiveFlowPalette.muted,
            fontSize: 12,
            height: 1.5,
          ),
        ),
      ],
    );

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          heading,
          if (trailing != null) ...[const SizedBox(height: 14), trailing!],
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: heading),
        if (trailing != null) ...[const SizedBox(width: 18), trailing!],
      ],
    );
  }
}

class _ClaimChips extends StatelessWidget {
  const _ClaimChips({required this.isMobile});

  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final claims = [
      (
        Icons.hub_outlined,
        isMobile ? 'Vendor neutral' : 'Vendor-neutral design',
      ),
      (
        Icons.route_outlined,
        isMobile ? 'Reservation routing' : 'Reservation-based routing',
      ),
      (Icons.healing_outlined, 'Local recovery'),
      (Icons.subject_outlined, 'Explainable decisions'),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final claim in claims)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: HiveFlowPalette.surface,
              border: Border.all(color: HiveFlowPalette.border),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(claim.$1, size: 14, color: HiveFlowPalette.mint),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    claim.$2,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: HiveFlowPalette.text,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _RunControls extends StatelessWidget {
  const _RunControls({required this.controller, required this.compact});

  final HiveFlowDemoController controller;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: controller.reset,
          icon: const Icon(Icons.restart_alt_rounded, size: 16),
          label: const Text('Reset demo'),
          style: OutlinedButton.styleFrom(
            foregroundColor: HiveFlowPalette.text,
            side: const BorderSide(color: HiveFlowPalette.border),
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 11 : 15,
              vertical: 13,
            ),
            textStyle: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        FilledButton.icon(
          onPressed: controller.toggleRun,
          icon: Icon(
            controller.isRunning
                ? Icons.pause_rounded
                : Icons.play_arrow_rounded,
            size: 17,
          ),
          label: Text(
            controller.isRunning ? 'Pause simulation' : 'Resume simulation',
          ),
          style: FilledButton.styleFrom(
            backgroundColor: HiveFlowPalette.lime,
            foregroundColor: HiveFlowPalette.sidebar,
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 12 : 16,
              vertical: 13,
            ),
            textStyle: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.controller, required this.isMobile});

  final HiveFlowDemoController controller;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width < 300
            ? 1
            : isMobile
            ? 2
            : width < 900
            ? 3
            : 5;
        const gap = 11.0;
        final cardWidth = (width - gap * (columns - 1)) / columns;
        final stats = [
          _KpiData(
            'ROBOTS ONLINE',
            '${controller.activeRobots}/${controller.robots.length}',
            'of ${controller.robots.length} in sample fleet',
            Icons.smart_toy_outlined,
            HiveFlowPalette.mint,
          ),
          _KpiData(
            'ORDERS COMPLETED',
            '${controller.completedOrders}',
            'completed in this preview run',
            Icons.inventory_2_outlined,
            HiveFlowPalette.blue,
          ),
          _KpiData(
            'DISTANCE TRAVELLED',
            '${controller.distanceTravelled} steps',
            'sample grid distance this run',
            Icons.straighten_rounded,
            HiveFlowPalette.amber,
          ),
          _KpiData(
            'RUSH ORDERS',
            '${controller.rushOrders}',
            'priority jobs still active',
            Icons.bolt_rounded,
            HiveFlowPalette.violet,
          ),
          _KpiData(
            'ROUTE CONFLICTS',
            '${controller.routeConflicts}',
            controller.mode == PlannerMode.hiveflow
                ? 'HiveFlow reserved plan'
                : 'measured in baseline preview',
            Icons.alt_route_rounded,
            HiveFlowPalette.violet,
          ),
        ];

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final stat in stats)
              SizedBox(
                width: cardWidth,
                child: _KpiCard(data: stat),
              ),
          ],
        );
      },
    );
  }
}

class _KpiData {
  const _KpiData(this.label, this.value, this.note, this.icon, this.color);

  final String label;
  final String value;
  final String note;
  final IconData icon;
  final Color color;
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.data});

  final _KpiData data;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  data.label,
                  style: const TextStyle(
                    color: HiveFlowPalette.muted,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.9,
                  ),
                ),
              ),
              Icon(data.icon, color: data.color, size: 17),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            data.value,
            style: const TextStyle(
              color: HiveFlowPalette.text,
              fontSize: 25,
              height: 1,
              letterSpacing: -0.8,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            data.note,
            style: const TextStyle(color: HiveFlowPalette.muted, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _ResponsiveRow extends StatelessWidget {
  const _ResponsiveRow({
    required this.isMobile,
    required this.left,
    required this.right,
    required this.leftFlex,
    required this.rightFlex,
  });

  final bool isMobile;
  final Widget left;
  final Widget right;
  final int leftFlex;
  final int rightFlex;

  @override
  Widget build(BuildContext context) {
    if (isMobile) {
      return Column(children: [left, const SizedBox(height: 14), right]);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: leftFlex, child: left),
        const SizedBox(width: 15),
        Expanded(flex: rightFlex, child: right),
      ],
    );
  }
}

class _MapCard extends StatelessWidget {
  const _MapCard({required this.controller, required this.height});

  final HiveFlowDemoController controller;
  final double height;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeading(
            title: 'Warehouse floor',
            subtitle: 'Robot position → assigned pickup shelf · sample layout',
            trailing: _ModeBadge(mode: controller.mode),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: height,
            width: double.infinity,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  color: HiveFlowPalette.surfaceInset,
                ),
                child: WarehouseMap(
                  robots: controller.robots,
                  isAisleBlocked: controller.isAisleBlocked,
                  mode: controller.mode,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const _MapLegend(),
          const SizedBox(height: 18),
          _MissionList(robots: controller.robots),
        ],
      ),
    );
  }
}

class _MapLegend extends StatelessWidget {
  const _MapLegend();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      runSpacing: 8,
      children: const [
        _LegendItem(
          color: HiveFlowPalette.mint,
          label: 'Robot + route',
          icon: Icons.smart_toy_rounded,
        ),
        _LegendItem(
          color: HiveFlowPalette.amber,
          label: 'Parcel pickup',
          icon: Icons.inventory_2_rounded,
        ),
        _LegendItem(
          color: HiveFlowPalette.red,
          label: 'Unavailable',
          icon: Icons.power_off_rounded,
        ),
        _LegendItem(
          color: HiveFlowPalette.red,
          label: 'Blocked aisle',
          icon: Icons.block_rounded,
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
    required this.icon,
  });

  final Color color;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(color: HiveFlowPalette.muted, fontSize: 9),
        ),
      ],
    );
  }
}

class _MissionList extends StatelessWidget {
  const _MissionList({required this.robots});

  final List<FleetRobot> robots;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _CardHeading(
          title: 'Live pick missions',
          subtitle: 'Tote, current robot position, and assigned pickup cell',
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final itemWidth = constraints.maxWidth > 640
                ? (constraints.maxWidth - 10) / 2
                : constraints.maxWidth;
            return Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                for (final robot in robots)
                  SizedBox(
                    width: itemWidth,
                    child: _MissionTile(robot: robot),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _MissionTile extends StatelessWidget {
  const _MissionTile({required this.robot});

  final FleetRobot robot;

  @override
  Widget build(BuildContext context) {
    final color = switch (robot.state) {
      RobotState.moving => HiveFlowPalette.mint,
      RobotState.picking => HiveFlowPalette.amber,
      RobotState.idle => HiveFlowPalette.muted,
      RobotState.failed => HiveFlowPalette.red,
    };
    final status = switch (robot.state) {
      RobotState.moving => 'ON ROUTE',
      RobotState.picking => 'AT PICKUP',
      RobotState.idle => 'IDLE',
      RobotState.failed => 'OFFLINE',
    };
    final hasTask = robot.task != 'STANDBY';
    final destination = robot.goal;
    final destinationLabel = hasTask
        ? 'PICKUP  (${destination.x}, ${destination.y})'
        : 'No parcel assigned';

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: HiveFlowPalette.surfaceInset,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: HiveFlowPalette.border),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(Icons.smart_toy_rounded, color: color, size: 18),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      robot.id,
                      style: const TextStyle(
                        color: HiveFlowPalette.text,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        robot.state == RobotState.failed
                            ? 'Task reassigned to fleet'
                            : hasTask
                            ? robot.load
                            : robot.task,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: HiveFlowPalette.muted,
                          fontSize: 9,
                        ),
                      ),
                    ),
                    Text(
                      status,
                      style: TextStyle(
                        color: color,
                        fontSize: 7,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  hasTask
                      ? 'FROM (${robot.position.x}, ${robot.position.y})  →  $destinationLabel'
                      : 'Position (${robot.position.x}, ${robot.position.y})',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: HiveFlowPalette.subtle,
                    fontSize: 8,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FleetHealthCard extends StatelessWidget {
  const _FleetHealthCard({required this.controller});

  final HiveFlowDemoController controller;

  @override
  Widget build(BuildContext context) {
    final moving = controller.movingRobots;
    final online = controller.activeRobots;
    return _SurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardHeading(
            title: 'Fleet health',
            subtitle: 'Preview snapshot',
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              SizedBox(
                width: 76,
                height: 76,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: online / controller.robots.length,
                        strokeWidth: 7,
                        backgroundColor: HiveFlowPalette.border,
                        valueColor: const AlwaysStoppedAnimation(
                          HiveFlowPalette.mint,
                        ),
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$online',
                          style: const TextStyle(
                            color: HiveFlowPalette.text,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Text(
                          'online',
                          style: TextStyle(
                            color: HiveFlowPalette.muted,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: [
                    _HealthLine(
                      label: 'Moving',
                      value: '$moving robots',
                      color: HiveFlowPalette.mint,
                    ),
                    const SizedBox(height: 12),
                    _HealthLine(
                      label: 'Picking',
                      value:
                          '${controller.robots.where((r) => r.state == RobotState.picking).length} robots',
                      color: HiveFlowPalette.amber,
                    ),
                    const SizedBox(height: 12),
                    _HealthLine(
                      label: 'Idle / yielding',
                      value:
                          '${controller.robots.where((r) => r.state == RobotState.idle).length} robots',
                      color: HiveFlowPalette.muted,
                    ),
                    const SizedBox(height: 12),
                    _HealthLine(
                      label: 'Unavailable',
                      value:
                          '${controller.robots.where((r) => r.state == RobotState.failed).length} robots',
                      color: HiveFlowPalette.red,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 17),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: HiveFlowPalette.surfaceInset,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: HiveFlowPalette.blue, size: 15),
                SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'Sample fleet state · no live robot connection',
                    style: TextStyle(color: HiveFlowPalette.muted, fontSize: 9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HealthLine extends StatelessWidget {
  const _HealthLine({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: HiveFlowPalette.muted, fontSize: 10),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: HiveFlowPalette.text,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ModeBadge extends StatelessWidget {
  const _ModeBadge({required this.mode});

  final PlannerMode mode;

  @override
  Widget build(BuildContext context) {
    final isHiveFlow = mode == PlannerMode.hiveflow;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: isHiveFlow
            ? HiveFlowPalette.surfaceRaised
            : HiveFlowPalette.surfaceRaised,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isHiveFlow ? 'HIVEFLOW PREVIEW' : 'BASELINE PREVIEW',
        style: TextStyle(
          color: isHiveFlow ? HiveFlowPalette.mint : HiveFlowPalette.subtle,
          fontSize: 8,
          letterSpacing: 0.55,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _DecisionCard extends StatelessWidget {
  const _DecisionCard({
    required this.decisions,
    required this.compact,
    required this.onViewAll,
  });

  final List<DecisionEntry> decisions;
  final bool compact;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeading(
            title: 'Decision feed',
            subtitle: 'Human-readable activity',
            trailing: TextButton(
              onPressed: onViewAll,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(40, 30),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'View all',
                style: TextStyle(
                  color: HiveFlowPalette.mint,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          for (final entry in decisions)
            _DecisionTile(entry: entry, compact: compact),
          const SizedBox(height: 3),
          const Text(
            'Example decision text · AI-written explanations are planned.',
            style: TextStyle(
              color: HiveFlowPalette.subtle,
              fontSize: 9,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _DecisionTile extends StatelessWidget {
  const _DecisionTile({required this.entry, required this.compact});

  final DecisionEntry entry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = Color(entry.color);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 29,
            height: 29,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(entry.icon, color: color, size: 15),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: HiveFlowPalette.text,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  entry.description,
                  maxLines: compact ? 2 : 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: HiveFlowPalette.muted,
                    fontSize: 9,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  entry.time,
                  style: const TextStyle(
                    color: HiveFlowPalette.subtle,
                    fontSize: 8,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScenarioStrip extends StatelessWidget {
  const _ScenarioStrip({required this.controller, required this.isMobile});

  final HiveFlowDemoController controller;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardHeading(
            title: 'Try a scenario',
            subtitle: 'Interactive controls update this local preview only',
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: [
              _ScenarioButton(
                icon: Icons.block_rounded,
                label: controller.isAisleBlocked
                    ? 'Reopen Aisle 3'
                    : 'Block Aisle 3',
                color: HiveFlowPalette.amber,
                onTap: () => controller.applyEvent(DemoEvent.blockAisle),
              ),
              _ScenarioButton(
                icon: Icons.power_settings_new_rounded,
                label: 'Simulate robot failure',
                color: HiveFlowPalette.red,
                onTap: () => controller.applyEvent(DemoEvent.robotFailure),
              ),
              _ScenarioButton(
                icon: Icons.bolt_rounded,
                label: 'Add rush order',
                color: HiveFlowPalette.violet,
                onTap: () => controller.applyEvent(DemoEvent.rushOrder),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScenarioButton extends StatelessWidget {
  const _ScenarioButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 15, color: color),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: HiveFlowPalette.text,
        side: const BorderSide(color: HiveFlowPalette.border),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        textStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

class _SimulationPage extends StatelessWidget {
  const _SimulationPage({required this.controller, required this.isMobile});

  final HiveFlowDemoController controller;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    return _PageScroll(
      isMobile: isMobile,
      children: [
        _PageHeading(
          eyebrow: 'PROTOTYPE WALKTHROUGH',
          title: 'Same warehouse. Two approaches.',
          description: 'Switch the planner preview, trigger an event, and inspect the sample fleet state.',
          isMobile: isMobile,
          trailing: _RunControls(controller: controller, compact: isMobile),
        ),
        const SizedBox(height: 18),
        _SurfaceCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _CardHeading(
                title: 'Planner comparison',
                subtitle: 'Visual concept only · live baseline and planner engines are not connected',
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  _PlannerButton(
                    label: 'HiveFlow preview',
                    selected: controller.mode == PlannerMode.hiveflow,
                    onTap: () => controller.setMode(PlannerMode.hiveflow),
                  ),
                  _PlannerButton(
                    label: 'Baseline preview',
                    selected: controller.mode == PlannerMode.baseline,
                    onTap: () => controller.setMode(PlannerMode.baseline),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _ComparisonMaps(controller: controller, isMobile: isMobile),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _ScenarioStrip(controller: controller, isMobile: isMobile),
        const SizedBox(height: 16),
        const _HonestyNote(),
      ],
    );
  }
}

class _ComparisonMaps extends StatelessWidget {
  const _ComparisonMaps({required this.controller, required this.isMobile});

  final HiveFlowDemoController controller;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final baseline = _ComparisonMapCard(
      title: 'BASELINE',
      subtitle: 'Shortest path · no reservations',
      conflicts: controller.baselineComparisonConflicts,
      robots: controller.comparisonRobots(PlannerMode.baseline),
      isAisleBlocked: controller.isAisleBlocked,
      mode: PlannerMode.baseline,
      height: isMobile ? 240 : 380,
    );
    final hiveFlow = _ComparisonMapCard(
      title: 'HIVEFLOW',
      subtitle: 'Space-time A* · reserved routes',
      conflicts: controller.hiveFlowComparisonConflicts,
      robots: controller.comparisonRobots(PlannerMode.hiveflow),
      isAisleBlocked: controller.isAisleBlocked,
      mode: PlannerMode.hiveflow,
      height: isMobile ? 240 : 380,
    );

    return Column(
      children: [
        if (isMobile) ...[
          baseline,
          const SizedBox(height: 12),
          hiveFlow,
        ] else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: baseline),
              const SizedBox(width: 12),
              Expanded(child: hiveFlow),
            ],
          ),
        const SizedBox(height: 12),
        const _MapLegend(),
      ],
    );
  }
}

class _ComparisonMapCard extends StatelessWidget {
  const _ComparisonMapCard({
    required this.title,
    required this.subtitle,
    required this.conflicts,
    required this.robots,
    required this.isAisleBlocked,
    required this.mode,
    required this.height,
  });

  final String title;
  final String subtitle;
  final int conflicts;
  final List<FleetRobot> robots;
  final bool isAisleBlocked;
  final PlannerMode mode;
  final double height;

  @override
  Widget build(BuildContext context) {
    final isHiveFlow = mode == PlannerMode.hiveflow;
    final statusColor = conflicts == 0
        ? HiveFlowPalette.mint
        : HiveFlowPalette.amber;
    final status = conflicts == 0
        ? 'No path conflicts'
        : '$conflicts path conflict${conflicts == 1 ? '' : 's'}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: isHiveFlow
                    ? HiveFlowPalette.mint
                    : HiveFlowPalette.subtle,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                color: isHiveFlow
                    ? HiveFlowPalette.lime
                    : HiveFlowPalette.muted,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.9,
              ),
            ),
            const Spacer(),
            Text(
              status,
              style: TextStyle(
                color: statusColor,
                fontSize: 8,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          subtitle,
          style: const TextStyle(color: HiveFlowPalette.muted, fontSize: 9),
        ),
        const SizedBox(height: 9),
        SizedBox(
          height: height,
          width: double.infinity,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: HiveFlowPalette.surfaceInset,
              ),
              child: WarehouseMap(
                robots: robots,
                isAisleBlocked: isAisleBlocked,
                mode: mode,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PlannerButton extends StatelessWidget {
  const _PlannerButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: HiveFlowPalette.surfaceRaised,
      labelStyle: TextStyle(
        color: selected ? HiveFlowPalette.lime : HiveFlowPalette.muted,
        fontWeight: FontWeight.w700,
        fontSize: 10,
      ),
      side: BorderSide(
        color: selected ? HiveFlowPalette.border : HiveFlowPalette.border,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
    );
  }
}

class _FleetPage extends StatelessWidget {
  const _FleetPage({required this.controller, required this.isMobile});

  final HiveFlowDemoController controller;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    return _PageScroll(
      isMobile: isMobile,
      children: [
        _PageHeading(
          eyebrow: 'ROBOT FLEET',
          title: 'Every robot, at a glance.',
          description: 'A sample fleet roster for the dashboard prototype. Vendor adapters are planned.',
          isMobile: isMobile,
          trailing: _ScenarioButton(
            icon: Icons.power_settings_new_rounded,
            label: 'Simulate robot failure',
            color: HiveFlowPalette.red,
            onTap: () => controller.applyEvent(DemoEvent.robotFailure),
          ),
        ),
        const SizedBox(height: 18),
        _SurfaceCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CardHeading(
                title: 'Warehouse 01 · sample robots',
                subtitle: '${controller.activeRobots} online · local preview',
              ),
              const SizedBox(height: 15),
              for (final robot in controller.robots)
                _RobotListTile(robot: robot),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const _HonestyNote(),
      ],
    );
  }
}

class _RobotListTile extends StatelessWidget {
  const _RobotListTile({required this.robot});

  final FleetRobot robot;

  @override
  Widget build(BuildContext context) {
    final stateColor = switch (robot.state) {
      RobotState.moving => HiveFlowPalette.mint,
      RobotState.picking => HiveFlowPalette.amber,
      RobotState.idle => HiveFlowPalette.muted,
      RobotState.failed => HiveFlowPalette.red,
    };
    final stateText = switch (robot.state) {
      RobotState.moving => 'Moving',
      RobotState.picking => 'Picking',
      RobotState.idle => 'Idle',
      RobotState.failed => 'Unavailable',
    };

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: HiveFlowPalette.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 37,
            height: 37,
            decoration: BoxDecoration(
              color: HiveFlowPalette.surfaceRaised,
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.smart_toy_outlined,
              color: HiveFlowPalette.mint,
              size: 19,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  robot.id,
                  style: const TextStyle(
                    color: HiveFlowPalette.text,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  robot.task,
                  style: const TextStyle(
                    color: HiveFlowPalette.muted,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
          if (MediaQuery.sizeOf(context).width > 520)
            Expanded(
              child: Text(
                '${robot.battery}% battery',
                style: const TextStyle(
                  color: HiveFlowPalette.muted,
                  fontSize: 10,
                ),
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: stateColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              stateText,
              style: TextStyle(
                color: stateColor,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DecisionsPage extends StatelessWidget {
  const _DecisionsPage({required this.controller, required this.isMobile});

  final HiveFlowDemoController controller;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    return _PageScroll(
      isMobile: isMobile,
      children: [
        _PageHeading(
          eyebrow: 'EXPLAINABLE FLEET',
          title: 'A reason behind every move.',
          description: 'Structured sample events rendered as plain language. AI-generated explanations are planned, not connected.',
          isMobile: isMobile,
        ),
        const SizedBox(height: 18),
        _DecisionCard(
          decisions: controller.decisions,
          compact: false,
          onViewAll: () {},
        ),
        const SizedBox(height: 13),
        const _HonestyNote(),
      ],
    );
  }
}

class _HonestyNote extends StatelessWidget {
  const _HonestyNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: HiveFlowPalette.surfaceRaised,
        border: Border.all(color: HiveFlowPalette.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline, size: 15, color: HiveFlowPalette.amber),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Seeded prototype only: assignment and route planning run locally; no Node.js API, PostgreSQL, or live warehouse telemetry is connected.',
              style: TextStyle(
                color: HiveFlowPalette.muted,
                fontSize: 9,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardHeading extends StatelessWidget {
  const _CardHeading({
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: HiveFlowPalette.text,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: HiveFlowPalette.muted,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ),
        trailing ?? const SizedBox.shrink(),
      ],
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HiveFlowPalette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HiveFlowPalette.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 16,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _PageScroll extends StatelessWidget {
  const _PageScroll({required this.children, required this.isMobile});

  final List<Widget> children;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = isMobile ? 18.0 : 30.0;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            23,
            horizontalPadding,
            26,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SmallLabel extends StatelessWidget {
  const _SmallLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 10),
      child: Text(
        text,
        style: const TextStyle(
          color: HiveFlowPalette.muted,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
