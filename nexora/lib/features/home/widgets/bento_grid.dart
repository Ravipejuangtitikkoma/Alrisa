import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nexora/core/design_tokens.dart';
import 'package:nexora/core/utils/snackbar_utils.dart';
import 'package:nexora/services/mqtt_service.dart';
import 'package:nexora/services/device_manager_service.dart';
import 'water_card.dart';

/// Bento Grid Asimetris dengan Animasi Vektor Minimalis & Dukungan Penuh Multi-Perangkat (Lampu, Pompa, Pintu, Gorden)
class BentoGrid extends StatelessWidget {
  const BentoGrid({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Baris 1: Water Card (Multi-Pompa) & Dynamic Light Card (Multi-Lampu dengan Dimmer & Glow)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Expanded(
              child: WaterCard(),
            ),
            SizedBox(width: 14),
            Expanded(
              child: DynamicLightSlot(),
            ),
          ],
        ),

        const SizedBox(height: 14),

        // Baris 2: Dua Kartu Mini Scene Animasi (Pintu Geser Dinamis & Gorden Dinamis)
        Row(
          children: const [
            Expanded(
              child: DynamicSlidingDoorSlot(),
            ),
            SizedBox(width: 14),
            Expanded(
              child: DynamicCurtainSlot(),
            ),
          ],
        ),
      ],
    );
  }
}

// =========================================================================
// 1. SLOT LAMPU PINTAR DINAMIS (Mendukung Multi-Lampu dengan Slider Dimmer)
// =========================================================================
class DynamicLightSlot extends StatefulWidget {
  const DynamicLightSlot({Key? key}) : super(key: key);

  @override
  State<DynamicLightSlot> createState() => _DynamicLightSlotState();
}

class _DynamicLightSlotState extends State<DynamicLightSlot> {
  late PageController _pageController;
  int _currentIndex = 0;
  List<CustomDeviceItem> _lights = [];
  StreamSubscription<List<CustomDeviceItem>>? _deviceSub;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _loadLights();

    _deviceSub = DeviceManagerService().devicesStream.listen((_) {
      if (!mounted) return;
      _loadLights();
    });
  }

  void _loadLights() {
    final devLights = DeviceManagerService().lights;
    setState(() {
      if (devLights.isNotEmpty) {
        _lights = List.from(devLights);
      } else {
        _lights = [
          CustomDeviceItem(
            id: 'lampu_teras',
            name: 'Lampu Teras Depan',
            type: DeviceType.light,
            hardwarePin: 'GPIO 4 (%QX0.3)',
            value: 80.0,
            isActive: true,
          ),
        ];
      }
      if (_currentIndex >= _lights.length) {
        _currentIndex = math.max(0, _lights.length - 1);
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _deviceSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_lights.isEmpty) {
      return const SizedBox.shrink();
    }

    if (_lights.length == 1) {
      return _SingleDimmerLightCard(
        device: _lights[0],
        showDots: false,
        currentIndex: 0,
        total: 1,
      );
    }

    return SizedBox(
      height: 196,
      child: PageView.builder(
        controller: _pageController,
        physics: const BouncingScrollPhysics(),
        itemCount: _lights.length,
        onPageChanged: (idx) {
          setState(() {
            _currentIndex = idx;
          });
        },
        itemBuilder: (context, index) {
          return _SingleDimmerLightCard(
            device: _lights[index],
            showDots: true,
            currentIndex: index,
            total: _lights.length,
          );
        },
      ),
    );
  }
}

/// Kartu Dimmer Lampu Tunggal Terisolasi (Performa Tinggi, Drag 60-120 FPS Buttery Smooth)
class _SingleDimmerLightCard extends StatefulWidget {
  final CustomDeviceItem device;
  final bool showDots;
  final int currentIndex;
  final int total;

  const _SingleDimmerLightCard({
    Key? key,
    required this.device,
    required this.showDots,
    required this.currentIndex,
    required this.total,
  }) : super(key: key);

  @override
  State<_SingleDimmerLightCard> createState() => _SingleDimmerLightCardState();
}

class _SingleDimmerLightCardState extends State<_SingleDimmerLightCard> {
  double _brightness = 0.80; // 0.0 - 1.0
  StreamSubscription<DeviceStateEvent>? _mqttSub;

  @override
  void initState() {
    super.initState();
    _syncInitialState();

    _mqttSub = MqttService().stateStream.listen((event) {
      if (event.deviceId == widget.device.id && mounted) {
        setState(() {
          if (event.payload.value != null) {
            _brightness = (event.payload.value! / 100.0).clamp(0.0, 1.0);
          } else {
            _brightness = event.payload.state ? 0.80 : 0.0;
          }
        });
      }
    });
  }

  void _syncInitialState() {
    final mqttState = MqttService().getDeviceState(widget.device.id);
    if (mqttState != null) {
      _brightness = (mqttState.value ?? (mqttState.state ? 80 : 0)) / 100.0;
    } else {
      _brightness = widget.device.isActive ? (widget.device.value / 100.0).clamp(0.0, 1.0) : 0.0;
    }
  }

  @override
  void didUpdateWidget(covariant _SingleDimmerLightCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.device.id != widget.device.id) {
      _syncInitialState();
    }
  }

  @override
  void dispose() {
    _mqttSub?.cancel();
    super.dispose();
  }

  void _toggleLight() {
    HapticFeedback.lightImpact();
    final bool isLightOn = _brightness > 0.0;
    final nextState = !isLightOn;

    setState(() {
      _brightness = nextState ? 0.80 : 0.0;
    });

    final brightnessVal = nextState ? 80 : 0;
    MqttService().publishSet(widget.device.id, state: nextState, value: brightnessVal);
    DeviceManagerService().updateState(
      widget.device.id,
      isActive: nextState,
      value: brightnessVal.toDouble(),
      statusText: nextState ? 'Menyala $brightnessVal%' : 'Mati',
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isLightOn = _brightness > 0.0;
    final int brightnessPercentage = (_brightness * 100).round();

    return RepaintBoundary(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        height: 196,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isLightOn ? NexoraTokens.brandCyanSubtle : NexoraTokens.surface,
          borderRadius: NexoraTokens.borderRadiusCard,
          border: Border.all(
            color: isLightOn ? NexoraTokens.brandCyanBorder : NexoraTokens.cardBorder,
            width: isLightOn ? 1.5 : 1.0,
          ),
          boxShadow: isLightOn
              ? NexoraTokens.cardShadowActive(NexoraTokens.brandCyan)
              : NexoraTokens.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Baris Atas: Ikon Bohlam & Status / Dots Indikator
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Ikon Bohlam dengan Live Radial Glow
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isLightOn ? NexoraTokens.brandCyanBorder : NexoraTokens.cardBorder,
                    ),
                    boxShadow: [
                      if (isLightOn)
                        BoxShadow(
                          color: NexoraTokens.brandCyan.withOpacity(0.35 * _brightness),
                          blurRadius: 18 * _brightness,
                          spreadRadius: 3 * _brightness,
                        ),
                    ],
                  ),
                  child: Icon(
                    Icons.lightbulb_outline,
                    size: 20,
                    color: isLightOn ? NexoraTokens.brandCyan : NexoraTokens.inkMuted,
                  ),
                ),

                const SizedBox(width: 6),

                // Dots & Badge Status
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.showDots) ...[
                        Row(
                          children: List.generate(widget.total, (i) {
                            return Container(
                              margin: const EdgeInsets.only(right: 3),
                              width: i == widget.currentIndex ? 10 : 4,
                              height: 4,
                              decoration: BoxDecoration(
                                color: i == widget.currentIndex
                                    ? NexoraTokens.brandCyan
                                    : Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(width: 6),
                      ],
                      GestureDetector(
                        onTap: _toggleLight,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isLightOn ? NexoraTokens.brandCyanBorder : NexoraTokens.cardBorder,
                            ),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              isLightOn ? 'Menyala $brightnessPercentage%' : 'Mati',
                              maxLines: 1,
                              style: TextStyle(
                                fontFamily: NexoraTokens.fontFamilySans,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isLightOn ? NexoraTokens.brandCyan : NexoraTokens.statusGray,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Slider Dimmer Halus Terisolasi
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 4,
                    activeTrackColor: NexoraTokens.brandCyan,
                    inactiveTrackColor: NexoraTokens.cardBorder,
                    thumbColor: Colors.white,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
                    overlayColor: NexoraTokens.brandCyan.withOpacity(0.12),
                  ),
                  child: Slider(
                    value: _brightness,
                    min: 0.0,
                    max: 1.0,
                    onChanged: (val) {
                      setState(() {
                        _brightness = (val < 0.02) ? 0.0 : val;
                      });
                    },
                    onChangeEnd: (val) {
                      final cleanVal = (val < 0.02) ? 0.0 : val;
                      final state = cleanVal > 0.0;
                      final brightnessInt = (cleanVal * 100).round();
                      if (MqttService().isConnected) {
                        MqttService().publishSet(widget.device.id, state: state, value: brightnessInt);
                        DeviceManagerService().updateState(
                          widget.device.id,
                          isActive: state,
                          value: brightnessInt.toDouble(),
                          statusText: state ? 'Menyala $brightnessInt%' : 'Mati',
                        );
                      } else {
                        showOfflineWarning(context, widget.device.name);
                      }
                    },
                  ),
                ),
                Text(
                  widget.device.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: NexoraTokens.fontFamilySans,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: NexoraTokens.ink,
                    letterSpacing: -0.2,
                  ),
                ),
                Text(
                  isLightOn ? 'Intensitas Cahaya $brightnessPercentage%' : 'Siaga • Ketuk untuk nyalakan',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: NexoraTokens.fontFamilySans,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: NexoraTokens.inkMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// =========================================================================
// 2. SLOT PINTU GESER DINAMIS (Mendukung Multi-Pintu Geser)
// =========================================================================
class DynamicSlidingDoorSlot extends StatefulWidget {
  const DynamicSlidingDoorSlot({Key? key}) : super(key: key);

  @override
  State<DynamicSlidingDoorSlot> createState() => _DynamicSlidingDoorSlotState();
}

class _DynamicSlidingDoorSlotState extends State<DynamicSlidingDoorSlot> {
  late PageController _pageController;
  int _currentIndex = 0;
  List<CustomDeviceItem> _doors = [];
  StreamSubscription<List<CustomDeviceItem>>? _deviceSub;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _loadDoors();

    _deviceSub = DeviceManagerService().devicesStream.listen((_) {
      if (!mounted) return;
      _loadDoors();
    });
  }

  void _loadDoors() {
    final devDoors = DeviceManagerService().slidingDoors;
    setState(() {
      if (devDoors.isNotEmpty) {
        _doors = List.from(devDoors);
      } else {
        _doors = [
          CustomDeviceItem(
            id: 'pintu_geser',
            name: 'Pintu Geser Ruang Tamu',
            type: DeviceType.slidingDoor,
            hardwarePin: 'GPIO 5 (%QX0.1)',
            statusText: 'Terkunci',
          ),
        ];
      }
      if (_currentIndex >= _doors.length) {
        _currentIndex = math.max(0, _doors.length - 1);
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _deviceSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_doors.isEmpty) return const SizedBox.shrink();

    if (_doors.length == 1) {
      return _SingleSlidingDoorCard(
        device: _doors[0],
        showDots: false,
        currentIndex: 0,
        total: 1,
      );
    }

    return SizedBox(
      height: 86,
      child: PageView.builder(
        controller: _pageController,
        physics: const BouncingScrollPhysics(),
        itemCount: _doors.length,
        onPageChanged: (idx) {
          setState(() {
            _currentIndex = idx;
          });
        },
        itemBuilder: (context, index) {
          return _SingleSlidingDoorCard(
            device: _doors[index],
            showDots: true,
            currentIndex: index,
            total: _doors.length,
          );
        },
      ),
    );
  }
}

class _SingleSlidingDoorCard extends StatefulWidget {
  final CustomDeviceItem device;
  final bool showDots;
  final int currentIndex;
  final int total;

  const _SingleSlidingDoorCard({
    Key? key,
    required this.device,
    required this.showDots,
    required this.currentIndex,
    required this.total,
  }) : super(key: key);

  @override
  State<_SingleSlidingDoorCard> createState() => _SingleSlidingDoorCardState();
}

class _SingleSlidingDoorCardState extends State<_SingleSlidingDoorCard> {
  bool _isOpen = false;
  StreamSubscription<DeviceStateEvent>? _mqttSub;

  @override
  void initState() {
    super.initState();
    _syncInitialState();

    _mqttSub = MqttService().stateStream.listen((event) {
      if (event.deviceId == widget.device.id && mounted) {
        setState(() {
          _isOpen = event.payload.state;
        });
      }
    });
  }

  void _syncInitialState() {
    final mqttState = MqttService().getDeviceState(widget.device.id);
    if (mqttState != null) {
      _isOpen = mqttState.state;
    } else {
      _isOpen = widget.device.isActive;
    }
  }

  @override
  void didUpdateWidget(covariant _SingleSlidingDoorCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.device.id != widget.device.id) {
      _syncInitialState();
    }
  }

  @override
  void dispose() {
    _mqttSub?.cancel();
    super.dispose();
  }

  void _toggleDoor() {
    HapticFeedback.lightImpact();
    final nextState = !_isOpen;

    setState(() {
      _isOpen = nextState;
    });

    MqttService().publishSet(widget.device.id, state: nextState);
    DeviceManagerService().updateState(
      widget.device.id,
      isActive: nextState,
      statusText: nextState ? 'Terbuka' : 'Terkunci',
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggleDoor,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _isOpen ? NexoraTokens.brandCyanSubtle : NexoraTokens.surface,
          borderRadius: NexoraTokens.borderRadiusCard,
          border: Border.all(
            color: _isOpen ? NexoraTokens.brandCyanBorder : NexoraTokens.cardBorder,
            width: _isOpen ? 1.5 : 1.0,
          ),
          boxShadow: _isOpen
              ? NexoraTokens.cardShadowActive(NexoraTokens.brandCyan)
              : NexoraTokens.cardShadow,
        ),
        child: Row(
          children: [
            // Mini Scene Pintu Geser Animasi
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isOpen ? NexoraTokens.brandCyanBorder : NexoraTokens.cardBorder,
                ),
              ),
              child: Center(
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.0, end: _isOpen ? 1.0 : 0.0),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeInOutCubic,
                  builder: (context, progress, child) {
                    return CustomPaint(
                      size: const Size(26, 26),
                      painter: _SlidingDoorPainter(progress: progress),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.device.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: NexoraTokens.fontFamilySans,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: NexoraTokens.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          _isOpen ? 'Terbuka' : 'Terkunci',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: NexoraTokens.fontFamilySans,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _isOpen ? NexoraTokens.brandCyan : NexoraTokens.statusGray,
                          ),
                        ),
                      ),
                      if (widget.showDots) ...[
                        const SizedBox(width: 6),
                        Row(
                          children: List.generate(widget.total, (i) {
                            return Container(
                              margin: const EdgeInsets.only(right: 2.5),
                              width: i == widget.currentIndex ? 8 : 3,
                              height: 3,
                              decoration: BoxDecoration(
                                color: i == widget.currentIndex
                                    ? NexoraTokens.brandCyan
                                    : Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            );
                          }),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =========================================================================
// 3. SLOT GORDEN DINAMIS (Mendukung Multi-Gorden)
// =========================================================================
class DynamicCurtainSlot extends StatefulWidget {
  const DynamicCurtainSlot({Key? key}) : super(key: key);

  @override
  State<DynamicCurtainSlot> createState() => _DynamicCurtainSlotState();
}

class _DynamicCurtainSlotState extends State<DynamicCurtainSlot> {
  late PageController _pageController;
  int _currentIndex = 0;
  List<CustomDeviceItem> _curtains = [];
  StreamSubscription<List<CustomDeviceItem>>? _deviceSub;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _loadCurtains();

    _deviceSub = DeviceManagerService().devicesStream.listen((_) {
      if (!mounted) return;
      _loadCurtains();
    });
  }

  void _loadCurtains() {
    final devCurtains = DeviceManagerService().curtains;
    setState(() {
      if (devCurtains.isNotEmpty) {
        _curtains = List.from(devCurtains);
      } else {
        _curtains = [
          CustomDeviceItem(
            id: 'gorden',
            name: 'Gorden Otomatis',
            type: DeviceType.curtain,
            hardwarePin: 'GPIO 18 (%QX0.2)',
            statusText: 'Tertutup',
          ),
        ];
      }
      if (_currentIndex >= _curtains.length) {
        _currentIndex = math.max(0, _curtains.length - 1);
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _deviceSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_curtains.isEmpty) return const SizedBox.shrink();

    if (_curtains.length == 1) {
      return _SingleCurtainCard(
        device: _curtains[0],
        showDots: false,
        currentIndex: 0,
        total: 1,
      );
    }

    return SizedBox(
      height: 86,
      child: PageView.builder(
        controller: _pageController,
        physics: const BouncingScrollPhysics(),
        itemCount: _curtains.length,
        onPageChanged: (idx) {
          setState(() {
            _currentIndex = idx;
          });
        },
        itemBuilder: (context, index) {
          return _SingleCurtainCard(
            device: _curtains[index],
            showDots: true,
            currentIndex: index,
            total: _curtains.length,
          );
        },
      ),
    );
  }
}

class _SingleCurtainCard extends StatefulWidget {
  final CustomDeviceItem device;
  final bool showDots;
  final int currentIndex;
  final int total;

  const _SingleCurtainCard({
    Key? key,
    required this.device,
    required this.showDots,
    required this.currentIndex,
    required this.total,
  }) : super(key: key);

  @override
  State<_SingleCurtainCard> createState() => _SingleCurtainCardState();
}

class _SingleCurtainCardState extends State<_SingleCurtainCard> {
  bool _isOpen = false;
  StreamSubscription<DeviceStateEvent>? _mqttSub;

  @override
  void initState() {
    super.initState();
    _syncInitialState();

    _mqttSub = MqttService().stateStream.listen((event) {
      if (event.deviceId == widget.device.id && mounted) {
        setState(() {
          _isOpen = event.payload.state;
        });
      }
    });
  }

  void _syncInitialState() {
    final mqttState = MqttService().getDeviceState(widget.device.id);
    if (mqttState != null) {
      _isOpen = mqttState.state;
    } else {
      _isOpen = widget.device.isActive;
    }
  }

  @override
  void didUpdateWidget(covariant _SingleCurtainCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.device.id != widget.device.id) {
      _syncInitialState();
    }
  }

  @override
  void dispose() {
    _mqttSub?.cancel();
    super.dispose();
  }

  void _toggleCurtain() {
    HapticFeedback.lightImpact();
    final nextState = !_isOpen;

    setState(() {
      _isOpen = nextState;
    });

    MqttService().publishSet(widget.device.id, state: nextState);
    DeviceManagerService().updateState(
      widget.device.id,
      isActive: nextState,
      statusText: nextState ? 'Terbuka' : 'Tertutup',
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggleCurtain,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _isOpen ? NexoraTokens.brandCyanSubtle : NexoraTokens.surface,
          borderRadius: NexoraTokens.borderRadiusCard,
          border: Border.all(
            color: _isOpen ? NexoraTokens.brandCyanBorder : NexoraTokens.cardBorder,
            width: _isOpen ? 1.5 : 1.0,
          ),
          boxShadow: _isOpen
              ? NexoraTokens.cardShadowActive(NexoraTokens.brandCyan)
              : NexoraTokens.cardShadow,
        ),
        child: Row(
          children: [
            // Mini Scene Gorden Animasi
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isOpen ? NexoraTokens.brandCyanBorder : NexoraTokens.cardBorder,
                ),
              ),
              child: Center(
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.0, end: _isOpen ? 1.0 : 0.0),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeInOutCubic,
                  builder: (context, progress, child) {
                    return CustomPaint(
                      size: const Size(26, 26),
                      painter: _CurtainsPainter(progress: progress),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.device.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: NexoraTokens.fontFamilySans,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: NexoraTokens.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          _isOpen ? 'Terbuka' : 'Tertutup',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: NexoraTokens.fontFamilySans,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _isOpen ? NexoraTokens.brandCyan : NexoraTokens.statusGray,
                          ),
                        ),
                      ),
                      if (widget.showDots) ...[
                        const SizedBox(width: 6),
                        Row(
                          children: List.generate(widget.total, (i) {
                            return Container(
                              margin: const EdgeInsets.only(right: 2.5),
                              width: i == widget.currentIndex ? 8 : 3,
                              height: 3,
                              decoration: BoxDecoration(
                                color: i == widget.currentIndex
                                    ? NexoraTokens.brandCyan
                                    : Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            );
                          }),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Painter Vektor Animasi Pintu Geser
class _SlidingDoorPainter extends CustomPainter {
  final double progress; // 0.0 (Terkunci/Tertutup) -> 1.0 (Terbuka)

  _SlidingDoorPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    // Kusen Luar
    final framePaint = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;

    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(1, 1, size.width - 2, size.height - 2), const Radius.circular(3)),
      framePaint,
    );

    // Cahaya Ruangan di Celah saat Terbuka
    if (progress > 0.05) {
      final lightPaint = Paint()
        ..color = const Color(0xFFFFF3DB).withOpacity(0.9 * progress)
        ..style = PaintingStyle.fill;

      canvas.drawRect(
        Rect.fromLTWH(2, 2, (size.width - 4) * 0.55 * progress, size.height - 4),
        lightPaint,
      );
    }

    // Panel Daun Pintu yang Bergeser
    final doorWidth = (size.width - 4) * 0.60;
    final slideDistance = (size.width - 4) - doorWidth;
    final currentX = 2.0 + (slideDistance * progress);

    final doorPaint = Paint()
      ..color = progress > 0.3 ? NexoraTokens.brandCyan : NexoraTokens.ink.withOpacity(0.7)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;

    final doorFill = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final doorRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(currentX, 2, doorWidth, size.height - 4),
      const Radius.circular(2),
    );

    canvas.drawRRect(doorRect, doorFill);
    canvas.drawRRect(doorRect, doorPaint);

    // Gagang Pintu
    final handlePaint = Paint()
      ..color = progress > 0.3 ? NexoraTokens.brandCyan : NexoraTokens.inkSecondary
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final handleX = currentX + (progress > 0.5 ? 4.0 : doorWidth - 4.0);
    canvas.drawLine(Offset(handleX, size.height * 0.42), Offset(handleX, size.height * 0.58), handlePaint);
  }

  @override
  bool shouldRepaint(covariant _SlidingDoorPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// Painter Vektor Animasi Gorden Menyibak
class _CurtainsPainter extends CustomPainter {
  final double progress; // 0.0 (Tertutup di tengah) -> 1.0 (Menyibak ke tepi)

  _CurtainsPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    // Rel / Batang Gorden di Atas
    final rodPaint = Paint()
      ..color = const Color(0xFF94A3B8)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(1, 3), Offset(size.width - 1, 3), rodPaint);

    // Jendela Kaca di Balik Gorden saat Terbuka
    if (progress > 0.05) {
      final windowPaint = Paint()
        ..color = const Color(0xFFE2F4FD).withOpacity(0.85 * progress)
        ..style = PaintingStyle.fill;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(3, 4, size.width - 6, size.height - 5),
          const Radius.circular(2),
        ),
        windowPaint,
      );

      // Garis silang jendela tipis
      final panePaint = Paint()
        ..color = Colors.white.withOpacity(0.7 * progress)
        ..strokeWidth = 1.0;
      canvas.drawLine(Offset(size.width / 2, 4), Offset(size.width / 2, size.height - 1), panePaint);
      canvas.drawLine(Offset(3, size.height * 0.52), Offset(size.width - 3, size.height * 0.52), panePaint);
    }

    // Panel Gorden Kiri & Kanan
    final halfWidth = size.width / 2 - 1.5;
    final currentPanelWidth = halfWidth - (halfWidth * 0.65 * progress);

    final curtainStroke = Paint()
      ..color = progress > 0.3 ? NexoraTokens.brandCyan : NexoraTokens.ink.withOpacity(0.75)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final curtainFill = Paint()
      ..color = Colors.white.withOpacity(0.92)
      ..style = PaintingStyle.fill;

    // Panel Kiri
    final leftPath = Path()
      ..moveTo(2, 4)
      ..lineTo(2 + currentPanelWidth, 4)
      ..quadraticBezierTo(2 + currentPanelWidth * 0.85, size.height * 0.5, 2 + currentPanelWidth, size.height - 1)
      ..lineTo(2, size.height - 1)
      ..close();

    canvas.drawPath(leftPath, curtainFill);
    canvas.drawPath(leftPath, curtainStroke);

    // Panel Kanan
    final rightX = size.width - 2 - currentPanelWidth;
    final rightPath = Path()
      ..moveTo(size.width - 2, 4)
      ..lineTo(rightX, 4)
      ..quadraticBezierTo(rightX + currentPanelWidth * 0.15, size.height * 0.5, rightX, size.height - 1)
      ..lineTo(size.width - 2, size.height - 1)
      ..close();

    canvas.drawPath(rightPath, curtainFill);
    canvas.drawPath(rightPath, curtainStroke);
  }

  @override
  bool shouldRepaint(covariant _CurtainsPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
