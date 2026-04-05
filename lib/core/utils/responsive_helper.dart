import 'package:flutter/material.dart';

class ResponsiveHelper {
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < 800;
  }

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= 800 && width < 1200;
  }

  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= 800;
  }

  static double getMainContentWidth(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 600) return width;
    if (width < 900) return width * 0.9;
    if (width < 1200) return 800;
    return width * 0.7;
  }

  static int getGridCrossAxisCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 600) return 1;
    if (width < 900) return 2;
    if (width < 1200) return 3;
    return 4;
  }

  static double getCardWidth(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 600) return double.infinity;
    if (width < 900) return (width - 48) / 2;
    return 250;
  }

  static EdgeInsets getScreenPadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 600) return const EdgeInsets.all(12);
    if (width < 1200) return const EdgeInsets.all(24);
    return const EdgeInsets.symmetric(horizontal: 48, vertical: 24);
  }
}

class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget desktop;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    required this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 800) {
          return mobile;
        } else if (tablet != null && constraints.maxWidth < 1200) {
          return tablet!;
        } else {
          return desktop;
        }
      },
    );
  }
}

class AdaptiveScaffold extends StatelessWidget {
  final PreferredSizeWidget appBar;
  final Widget? drawer;
  final Widget body;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;

  const AdaptiveScaffold({
    super.key,
    required this.appBar,
    this.drawer,
    required this.body,
    this.floatingActionButton,
    this.bottomNavigationBar,
  });

  @override
  Widget build(BuildContext context) {
    final isDesk = ResponsiveHelper.isDesktop(context);

    if (isDesk) {
      return Scaffold(
        appBar: appBar,
        body: Row(
          children: [
            if (drawer != null) SizedBox(width: 280, child: drawer),
            const VerticalDivider(width: 1),
            Expanded(child: body),
          ],
        ),
        floatingActionButton: floatingActionButton,
      );
    }

    return Scaffold(
      appBar: appBar,
      drawer: drawer,
      body: body,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}

class ResponsiveRow extends StatelessWidget {
  final List<Widget> children;
  final double spacing;
  final double runSpacing;

  const ResponsiveRow({
    super.key,
    required this.children,
    this.spacing = 16,
    this.runSpacing = 16,
  });

  @override
  Widget build(BuildContext context) {
    final isDesk = ResponsiveHelper.isDesktop(context);

    if (isDesk) {
      return Wrap(spacing: spacing, runSpacing: runSpacing, children: children);
    }

    return Column(
      children: children
          .map(
            (c) => Padding(
              padding: EdgeInsets.only(bottom: runSpacing),
              child: c,
            ),
          )
          .toList(),
    );
  }
}

class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final double spacing;
  final double runSpacing;
  final double Function(BuildContext)? childWidth;

  const ResponsiveGrid({
    super.key,
    required this.children,
    this.spacing = 16,
    this.runSpacing = 16,
    this.childWidth,
  });

  @override
  Widget build(BuildContext context) {
    final isDesk = ResponsiveHelper.isDesktop(context);

    if (isDesk) {
      return Wrap(spacing: spacing, runSpacing: runSpacing, children: children);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children
          .map(
            (c) => Padding(
              padding: EdgeInsets.only(bottom: runSpacing),
              child: c,
            ),
          )
          .toList(),
    );
  }
}
