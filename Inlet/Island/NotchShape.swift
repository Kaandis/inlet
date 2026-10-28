import SwiftUI

/// The island silhouette: concave "flares" where it meets the top edge of the
/// screen (so it reads as part of the hardware notch) and rounded bottom corners.
///
/// The shape's width includes both flares, so the body is `width - 2 * topRadius`.
struct NotchShape: Shape {
    var topRadius: CGFloat
    var bottomRadius: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topRadius, bottomRadius) }
        set {
            topRadius = newValue.first
            bottomRadius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let rt = min(topRadius, w / 4, h / 2)
        let rb = min(bottomRadius, (w - 2 * rt) / 2, h - rt)

        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.minX + rt, y: rect.minY + rt),
                       control: CGPoint(x: rect.minX + rt, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX + rt, y: rect.minY + h - rb))
        p.addQuadCurve(to: CGPoint(x: rect.minX + rt + rb, y: rect.minY + h),
                       control: CGPoint(x: rect.minX + rt, y: rect.minY + h))
        p.addLine(to: CGPoint(x: rect.minX + w - rt - rb, y: rect.minY + h))
        p.addQuadCurve(to: CGPoint(x: rect.minX + w - rt, y: rect.minY + h - rb),
                       control: CGPoint(x: rect.minX + w - rt, y: rect.minY + h))
        p.addLine(to: CGPoint(x: rect.minX + w - rt, y: rect.minY + rt))
        p.addQuadCurve(to: CGPoint(x: rect.minX + w, y: rect.minY),
                       control: CGPoint(x: rect.minX + w - rt, y: rect.minY))
        p.closeSubpath()
        return p
    }
}
