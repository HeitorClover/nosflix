import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_theme.dart';

/// Fundo com brilho na cor do perfil, do topo até o preto-avermelhado/rosado.
class AppBackground extends StatelessWidget {
  final Widget child;
  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final nx = context.nx;
    return SizedBox.expand(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [nx.glow, nx.base],
            stops: const [0, 0.55],
          ),
        ),
        child: child,
      ),
    );
  }
}

/// Logo "NOSFLIX" em degradê.
class Wordmark extends StatelessWidget {
  final double size;
  final Gradient? gradient;
  const Wordmark({super.key, this.size = 32, this.gradient});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (rect) => (gradient ?? context.nx.gradient).createShader(rect),
      child: Text(
        'NOSFLIX',
        style: GoogleFonts.bebasNeue(
          fontSize: size,
          letterSpacing: size * 0.1,
          color: Colors.white,
          height: 1,
        ),
      ),
    );
  }
}

/// Bolinha com a inicial do perfil, em degradê.
class ProfileAvatar extends StatelessWidget {
  final Profile profile;
  final double radius;
  const ProfileAvatar({super.key, required this.profile, this.radius = 20});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: profile.gradient,
        boxShadow: [BoxShadow(color: profile.seedColor.withValues(alpha: 0.45), blurRadius: radius * 0.8)],
      ),
      child: Text(
        profile.displayName[0],
        style: TextStyle(color: Colors.white, fontSize: radius * 0.95, fontWeight: FontWeight.w800),
      ),
    );
  }
}

/// Pílula de seleção (filtros e status): degradê quando selecionada.
class ChoicePill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  const ChoicePill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final nx = context.nx;
    final scheme = Theme.of(context).colorScheme;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            gradient: selected ? nx.gradient : null,
            color: selected ? null : Colors.white.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(999),
            boxShadow: selected
                ? [BoxShadow(color: scheme.primary.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 4))]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: selected ? Colors.white : scheme.onSurfaceVariant),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : scheme.onSurface.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Botão flutuante em degradê com brilho.
class GradientFab extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const GradientFab({super.key, required this.icon, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: context.nx.gradient,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [BoxShadow(color: scheme.primary.withValues(alpha: 0.5), blurRadius: 22, offset: const Offset(0, 8))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white),
                const SizedBox(width: 8),
                Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Título de seção com barrinha de destaque.
class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(gradient: context.nx.gradient, borderRadius: BorderRadius.circular(4)),
        ),
        const SizedBox(width: 10),
        Text(text, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}

/// Botão redondo translúcido (usado sobre imagens).
class GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;
  const GlassIconButton({super.key, required this.icon, required this.onPressed, this.tooltip});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Material(
        color: Colors.black.withValues(alpha: 0.45),
        shape: const CircleBorder(),
        child: IconButton(
          tooltip: tooltip,
          icon: Icon(icon, color: Colors.white, size: 20),
          onPressed: onPressed,
        ),
      ),
    );
  }
}
