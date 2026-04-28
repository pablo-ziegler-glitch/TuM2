import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../models/merchant_search_item.dart';
import 'map_controller.dart';
import 'map_state.dart';

class SearchGoogleMapView extends StatefulWidget {
  const SearchGoogleMapView({
    super.key,
    required this.merchants,
    required this.selectedMerchantId,
    required this.onMerchantSelected,
    required this.onMerchantOpen,
    required this.onListTap,
    required this.onRecenterTap,
    required this.onSearchThisAreaTap,
  });

  final List<MerchantSearchItem> merchants;
  final String? selectedMerchantId;
  final ValueChanged<String> onMerchantSelected;
  final ValueChanged<String> onMerchantOpen;
  final VoidCallback onListTap;
  final VoidCallback onRecenterTap;
  final VoidCallback onSearchThisAreaTap;

  @override
  State<SearchGoogleMapView> createState() => _SearchGoogleMapViewState();
}

class _SearchGoogleMapViewState extends State<SearchGoogleMapView> {
  final SearchMapController _mapController = SearchMapController();

  GoogleMapController? _googleMapController;
  CameraPosition? _cameraPosition;
  SearchMapState _mapState = SearchMapState.initial;
  bool _building = false;

  @override
  void initState() {
    super.initState();
    _cameraPosition = _resolveInitialCamera(widget.merchants);
  }

  @override
  void didUpdateWidget(covariant SearchGoogleMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.merchants != widget.merchants ||
        oldWidget.selectedMerchantId != widget.selectedMerchantId) {
      _rebuildMarkers();
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.merchants
        .where((merchant) {
          return merchant.merchantId == widget.selectedMerchantId;
        })
        .cast<MerchantSearchItem?>()
        .firstWhere(
          (item) => item != null,
          orElse: () => null,
        );

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: _cameraPosition!,
          myLocationButtonEnabled: false,
          mapToolbarEnabled: false,
          zoomControlsEnabled: false,
          markers: _mapState.markers,
          onMapCreated: (controller) async {
            _googleMapController = controller;
            await _rebuildMarkers();
          },
          onTap: (_) => widget.onMerchantSelected(''),
          onCameraMove: (position) {
            _cameraPosition = position;
          },
          onCameraIdle: _rebuildMarkers,
        ),
        Positioned(
          top: 12,
          left: 0,
          right: 0,
          child: Center(
            child: FilledButton.tonalIcon(
              onPressed: widget.onListTap,
              icon: const Icon(Icons.list),
              label: const Text('Ver lista'),
            ),
          ),
        ),
        Positioned(
          top: 64,
          right: 16,
          child: Column(
            children: [
              FloatingActionButton.small(
                heroTag: 'map_recenter_btn',
                onPressed: () async {
                  widget.onRecenterTap();
                  final target = selected != null &&
                          selected.lat != null &&
                          selected.lng != null
                      ? LatLng(selected.lat!, selected.lng!)
                      : _resolveInitialCamera(widget.merchants).target;
                  await _googleMapController?.animateCamera(
                    CameraUpdate.newCameraPosition(
                      CameraPosition(target: target, zoom: 14),
                    ),
                  );
                },
                child: const Icon(Icons.my_location),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: widget.onSearchThisAreaTap,
                child: const Text('Buscar aquí'),
              ),
            ],
          ),
        ),
        if (selected != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: _SelectedMerchantCard(
              merchant: selected,
              onOpenTap: () => widget.onMerchantOpen(selected.merchantId),
            ),
          ),
      ],
    );
  }

  Future<void> _rebuildMarkers() async {
    if (!mounted || _building) return;
    if (_googleMapController == null || _cameraPosition == null) return;

    _building = true;
    try {
      final pixelRatio = MediaQuery.of(context).devicePixelRatio;
      final bounds = await _safeVisibleRegion();
      final state = await _mapController.buildState(
        merchants: widget.merchants,
        viewportBounds: bounds,
        zoom: _cameraPosition!.zoom,
        pixelRatio: pixelRatio,
        selectedMerchantId: widget.selectedMerchantId,
        onMerchantTap: (merchantId) {
          if (merchantId.isEmpty) return;
          widget.onMerchantSelected(merchantId);
        },
        onClusterTap: (center, nextZoom) async {
          await _googleMapController?.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(target: center, zoom: nextZoom),
            ),
          );
        },
      );

      if (!mounted) return;
      setState(() {
        _mapState = state;
      });
    } finally {
      _building = false;
    }
  }

  Future<LatLngBounds?> _safeVisibleRegion() async {
    try {
      return await _googleMapController?.getVisibleRegion();
    } catch (_) {
      return null;
    }
  }

  CameraPosition _resolveInitialCamera(List<MerchantSearchItem> merchants) {
    final firstWithCoords = merchants.cast<MerchantSearchItem?>().firstWhere(
          (item) => item?.lat != null && item?.lng != null,
          orElse: () => null,
        );

    if (firstWithCoords != null) {
      return CameraPosition(
        target: LatLng(firstWithCoords.lat!, firstWithCoords.lng!),
        zoom: 14,
      );
    }

    return const CameraPosition(
      target: LatLng(-34.6037, -58.3816),
      zoom: 12,
    );
  }
}

class _SelectedMerchantCard extends StatelessWidget {
  const _SelectedMerchantCard({
    required this.merchant,
    required this.onOpenTap,
  });

  final MerchantSearchItem merchant;
  final VoidCallback onOpenTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.neutral900.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    merchant.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.labelMd.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    merchant.address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyXs.copyWith(
                      color: AppColors.neutral700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: onOpenTap,
              child: const Text('Ver ficha'),
            ),
          ],
        ),
      ),
    );
  }
}
