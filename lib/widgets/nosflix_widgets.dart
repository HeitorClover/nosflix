import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_theme.dart';

/// Fotos de fundo do app (ficam em images/).
enum BackdropPhoto {
  home('images/home.jpeg', Alignment(-0.1, -0.25)),
  search('images/search.png', Alignment(0, -0.75));

  final String asset;
  final Alignment alignment;
  const BackdropPhoto(this.asset, this.alignment);
}

/// Fundo do app. Sem [photo], é só o degradê do perfil. Com [photo], a foto
/// fica quase toda coberta pela cor do perfil (vermelho/rosa) e some no escuro
/// embaixo, pra o conteúdo continuar legível.
class AppBackground extends StatelessWidget {
  final Widget child;
  final BackdropPhoto? photo;
  const AppBackground({super.key, required this.child, this.photo});

  @override
  Widget build(BuildContext context) {
    final nx = context.nx;
    final scheme = Theme.of(context).colorScheme;
    return SizedBox.expand(
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [nx.glow, nx.base],
                stops: const [0, 0.55],
              ),
            ),
          ),
          if (photo != null) ...[
            Image.asset(
              photo!.asset,
              fit: BoxFit.cover,
              alignment: photo!.alignment,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
            // Banho de cor do perfil por cima da foto.
            ColoredBox(color: scheme.primaryContainer.withValues(alpha: 0.62)),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    scheme.primary.withValues(alpha: 0.18),
                    nx.base.withValues(alpha: 0.72),
                    nx.base.withValues(alpha: 0.96),
                  ],
                  stops: const [0, 0.38, 0.72],
                ),
              ),
            ),
          ],
          child,
        ],
      ),
    );
  }
}

/// Cartão de vidro: fundo desfocado e translúcido com borda fina.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double blur;
  final Color? borderColor;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 24,
    this.blur = 18,
    this.borderColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final border = BorderRadius.circular(radius);
    return ClipRRect(
      borderRadius: border,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: border,
            border: Border.all(color: borderColor ?? Colors.white.withValues(alpha: 0.12)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white.withValues(alpha: 0.11), Colors.white.withValues(alpha: 0.04)],
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: border,
              onTap: onTap,
              child: Padding(padding: padding, child: child),
            ),
          ),
        ),
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

/// Foto de perfil redonda com aro em degradê (cai na inicial se faltar a imagem).
class ProfileAvatar extends StatelessWidget {
  final Profile profile;
  final double radius;
  const ProfileAvatar({super.key, required this.profile, this.radius = 20});

  @override
  Widget build(BuildContext context) {
    final ring = (radius * 0.12).clamp(1.5, 3.5);
    return Container(
      width: radius * 2,
      height: radius * 2,
      padding: EdgeInsets.all(ring),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: profile.gradient,
        boxShadow: [BoxShadow(color: profile.seedColor.withValues(alpha: 0.45), blurRadius: radius * 0.8)],
      ),
      child: ClipOval(
        child: Image.asset(
          profile.photoAsset,
          fit: BoxFit.cover,
          alignment: const Alignment(0, -0.2),
          errorBuilder: (_, _, _) => Container(
            alignment: Alignment.center,
            color: profile.deepColor,
            child: Text(
              profile.displayName[0],
              style: TextStyle(color: Colors.white, fontSize: radius * 0.95, fontWeight: FontWeight.w800),
            ),
          ),
        ),
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
