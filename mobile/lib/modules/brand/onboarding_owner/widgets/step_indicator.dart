import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';

enum StepState { active, completed, future }

class StepIndicator extends StatelessWidget {
  final int currentStep; // 1-based
  final int totalSteps;

  const StepIndicator({
    super.key,
    required this.currentStep,
    this.totalSteps = 4,
  });

  StepState _stateFor(int step) {
    if (step < currentStep) return StepState.completed;
    if (step == currentStep) return StepState.active;
    return StepState.future;
  }

  Color _circleColor(StepState s) {
    switch (s) {
      case StepState.active:
        return AppColors.primary500;
      case StepState.completed:
        return AppColors.secondary500;
      case StepState.future:
        return AppColors.neutral300;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 1; i <= totalSteps; i++) ...[
          _StepCircle(
            number: i,
            state: _stateFor(i),
            color: _circleColor(_stateFor(i)),
          ),
          if (i < totalSteps) _StepConnector(completed: i < currentStep),
        ],
      ],
    );
  }
}

class _StepCircle extends StatelessWidget {
  final int number;
  final StepState state;
  final Color color;

  const _StepCircle({
    required this.number,
    required this.state,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Center(
        child: state == StepState.completed
            ? const Icon(Icons.check, color: Colors.white, size: 14)
            : Text(
                '$number',
                style: AppTextStyles.labelSm.copyWith(
                  color: state == StepState.future
                      ? AppColors.neutral600
                      : Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}

class _StepConnector extends StatelessWidget {
  final bool completed;
  const _StepConnector({required this.completed});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 2,
      color: completed ? AppColors.secondary500 : AppColors.neutral300,
    );
  }
}
