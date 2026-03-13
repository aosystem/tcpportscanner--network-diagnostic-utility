import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:tcpportscanner/parse_locale_tag.dart';
import 'package:tcpportscanner/scan_result.dart';
import 'package:tcpportscanner/setting_page.dart';
import 'package:tcpportscanner/theme_color.dart';
import 'package:tcpportscanner/theme_mode_number.dart';
import 'package:tcpportscanner/ad_manager.dart';
import 'package:tcpportscanner/loading_screen.dart';
import 'package:tcpportscanner/model.dart';
import 'package:tcpportscanner/main.dart';
import 'package:tcpportscanner/ad_banner_widget.dart';


class MainHomePage extends StatefulWidget {
  const MainHomePage({super.key});
  @override
  State<MainHomePage> createState() => _MainHomePageState();
}

class _MainHomePageState extends State<MainHomePage> {
  late AdManager _adManager;
  late ThemeColor _themeColor;
  bool _isReady = false;
  bool _isFirst = true;
  //
  final _ipController = TextEditingController(text: '192.168.1.1');
  final _portFromController = TextEditingController(text: '1');
  final _portToController = TextEditingController(text: '1024');
  bool _isScanning = false;
  List<ScanResult> _results = [];
  String? _errorMessage;
  int _scanningPort = 0;
  int _stopwatchSecond = 0;

  @override
  void initState() {
    super.initState();
    _initState();
  }

  void _initState() async {
    _adManager = AdManager();
    if (mounted) {
      setState(() {
        _isReady = true;
      });
    }
  }

  @override
  void dispose() {
    _ipController.dispose();
    _portFromController.dispose();
    _portToController.dispose();
    super.dispose();
  }

  Future<void> _startScan() async {
    final host = _ipController.text.trim();
    final fromStr = _portFromController.text.trim();
    final toStr = _portToController.text.trim();
    setState(() {
      _errorMessage = null;
      _results = [];
    });
    if (host.isEmpty || fromStr.isEmpty || toStr.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter an IP address and a port range.';
      });
      return;
    }
    int from;
    int to;
    try {
      from = int.parse(fromStr);
      to = int.parse(toStr);
      if (from < 1 || to > 65535 || from > to) {
        throw Exception();
      }
    } catch (_) {
      setState(() {
        _errorMessage = 'Invalid port range (must be between 1 and 65535).';
      });
      return;
    }
    setState(() {
      _isScanning = true;
      _results = [];
    });
    final List<ScanResult> tmpResults = [];
    final stopwatch = Stopwatch()..start();
    _stopwatchSecond = 0;
    for (int port = from; port <= to; port++) {
      if (!_isScanning) {
        break;
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _stopwatchSecond = stopwatch.elapsed.inSeconds;
        _scanningPort = port;
      });
      try {
        final isOpen = await _scanPort(host, port);
        if (isOpen) {
          tmpResults.add(ScanResult(port: port, open: true));
          setState(() {
            _results = List.from(tmpResults);
          });
        }
      } catch (_) {
      }
    }
    stopwatch.stop();
    if (!mounted) {
      return;
    }
    setState(() {
      _stopwatchSecond = stopwatch.elapsed.inSeconds;
      _isScanning = false;
    });
  }

  void _cancelScan() {
    setState(() {
      _isScanning = false;
    });
  }

  Future<bool> _scanPort(String host, int port) async {
    try {
      final stopwatch = Stopwatch()..start();
      final socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(milliseconds: 300),
      );
      stopwatch.stop();
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  void _openSetting() async {
    final updatedSettings = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SettingPage(),
      ),
    );
    if (updatedSettings != null) {
      if (mounted) {
        final mainState = context.findAncestorStateOfType<MainAppState>();
        if (mainState != null) {
          mainState
            ..locale = parseLocaleTag(Model.languageCode)
            ..themeMode = ThemeModeNumber.numberToThemeMode(Model.themeNumber)
            ..setState(() {});
        }
      }
      if (mounted) {
        setState(() {
          _isFirst = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isReady == false) {
      return const LoadingScreen();
    }
    if (_isFirst) {
      _isFirst = false;
      _themeColor = ThemeColor(context: context);
    }
    return Scaffold(
      backgroundColor: _themeColor.mainBackColor,
      body: Stack(children:[
        _buildBackground(),
        SafeArea(
          child: Column(children: [
            _buildAppBar(),
            _buildInput(),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => FocusScope.of(context).unfocus(),
                child: SingleChildScrollView(
                  child: _buildOutput(),
                ),
              ),
            ),
          ])
        )
      ]),
      bottomNavigationBar: AdBannerWidget(adManager: _adManager),
    );
  }

  Widget _buildBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_themeColor.mainBack2Color, _themeColor.mainBackColor],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        image: DecorationImage(
          image: AssetImage('assets/image/tile.png'),
          repeat: ImageRepeat.repeat,
          opacity: 0.1,
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    final t = Theme.of(context).textTheme;
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          const SizedBox(width: 16),
          Text('TCP PORT SCANNER', style: t.titleSmall?.copyWith(color: _themeColor.mainForeColor)),
          const Spacer(),
          IconButton(
            onPressed: _openSetting,
            icon: Icon(Icons.settings,color: _themeColor.mainForeColor.withValues(alpha: 0.6)),
          ),
        ],
      )
    );
  }

  Widget _buildInput() {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 16),
      child: Column(
        children: [
          TextField(
            controller: _ipController,
            decoration: InputDecoration(
              labelText: 'Target IP Address',
              hintText: 'Example: 192.168.1.1',
              hintStyle: TextStyle(
                color: t.hintColor.withValues(alpha: 0.4),
              ),
              border: OutlineInputBorder(),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: <TextInputFormatter>[
              TextInputFormatter.withFunction((oldValue, newValue) {
                final replaced = newValue.text.replaceAll(',', '.');
                return TextEditingValue(
                  text: replaced,
                  selection: TextSelection.collapsed(offset: replaced.length),
                );
              }),
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _portFromController,
                  decoration: InputDecoration(
                    labelText: 'Start Port',
                    hintText: '1',
                    hintStyle: TextStyle(
                      color: t.hintColor.withValues(alpha: 0.4),
                    ),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _portToController,
                  decoration: InputDecoration(
                    labelText: 'End Port',
                    hintText: '1024',
                    hintStyle: TextStyle(
                      color: t.hintColor.withValues(alpha: 0.4),
                    ),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _errorMessage!,
                style: TextStyle(color: t.colorScheme.error),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      side: BorderSide(
                        color: _themeColor.mainForeColor.withValues(alpha: 0.6),
                        width: 1.5,
                      ),
                    ),
                    onPressed: _isScanning ? null : _startScan,
                    icon: _isScanning
                      ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.search),
                    label: Text(
                      _isScanning ? 'Scanning… $_scanningPort' : 'Scan start',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      side: BorderSide(
                        color: _themeColor.mainForeColor.withValues(alpha: 0.6),
                        width: 1.5,
                      ),
                    ),
                    onPressed: _isScanning ? _cancelScan : null,
                    icon: const Icon(Icons.cancel),
                    label: const Text('Cancel'),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );

  }

  Widget _buildOutput() {
    return Column(children:[
      _buildMessage(),
      _buildResult(),
    ]);
  }

  Widget _buildMessage() {
    String text = '';
    if (_isScanning) {
      text = 'Scanning: ${_results.length} found (${_stopwatchSecond}sec)';
    } else {
      text = 'Scan complete: ${_results.length} found (${_stopwatchSecond}sec)';
    }
    return SizedBox(
      width: double.infinity,
      child: Card(
        margin: const EdgeInsets.only(left: 16, right: 16, top: 12),
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(text, style: const TextStyle(fontSize: 16),
          ),
        )
      )
    );
  }

  Widget _buildResult() {
    final text = _results.map((r) => 'Port ${r.port} Open').join('\n');
    return SizedBox(
      width: double.infinity,
      child: Card(
        margin: const EdgeInsets.only(left: 16, right: 16, top: 12),
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: SelectableText(
            text,
            style: const TextStyle(fontSize: 16),
          ),
        )
      )
    );
  }

}
