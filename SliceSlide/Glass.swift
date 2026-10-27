import SpriteKit
import UIKit

/// Cam/kristal görünümlü parça ve çekirdek dokularını ekran çözünürlüğünde çizer.
enum Glass {
    private static func format() -> UIGraphicsImageRendererFormat {
        let f = UIGraphicsImageRendererFormat()
        f.scale = UIScreen.main.scale
        f.opaque = false
        return f
    }

    /// Dönen değer: doku, noktadaki boyut, ağırlık merkezine denk gelen anchorPoint.
    static func piece(poly: [CGPoint], colors: [UIColor], sprinkles: Bool = false) -> (SKTexture, CGSize, CGPoint) {
        let pad: CGFloat = 28
        let xs = poly.map { $0.x }, ys = poly.map { $0.y }
        let minX = xs.min()!, maxX = xs.max()!, minY = ys.min()!, maxY = ys.max()!
        let size = CGSize(width: maxX - minX + 2 * pad, height: maxY - minY + 2 * pad)
        let c = Geo.centroid(poly)
        func map(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x - minX + pad, y: maxY - p.y + pad) }
        let pts = poly.map(map)
        let cm = map(c)
        let path = Geo.roundedPath(pts, radius: 11)
        let bbox = path.boundingBoxOfPath
        let cs = CGColorSpaceCreateDeviceRGB()

        let img = UIGraphicsImageRenderer(size: size, format: format()).image { r in
            let g = r.cgContext

            // 1) Dış parıltı + sütlü cam tabanı
            g.saveGState()
            g.setShadow(offset: .zero, blur: 20, color: UIColor.white.withAlphaComponent(0.6).cgColor)
            g.addPath(path)
            g.setFillColor(UIColor.white.withAlphaComponent(0.55).cgColor)
            g.fillPath()
            g.restoreGState()

            g.saveGState()
            g.addPath(path)
            g.clip()

            // 2) Renk geçişi
            let stops = colors.map { $0.withAlphaComponent(0.93).cgColor }
            let locs = (0..<stops.count).map { CGFloat($0) / CGFloat(max(stops.count - 1, 1)) }
            let grad = CGGradient(colorsSpace: cs, colors: stops as CFArray, locations: locs)!
            g.drawLinearGradient(grad, start: CGPoint(x: 0, y: bbox.minY), end: CGPoint(x: 0, y: bbox.maxY), options: [])

            // 2b) Şeker serpmesi (Pamuk Şeker seti)
            if sprinkles {
                let hues = [UIColor.white, UIColor(255, 110, 170), UIColor(255, 232, 140), UIColor(196, 176, 255), UIColor(160, 232, 214)]
                let count = min(46, Int(bbox.width * bbox.height / 700))
                for _ in 0..<count {
                    let p = CGPoint(x: .random(in: bbox.minX...bbox.maxX), y: .random(in: bbox.minY...bbox.maxY))
                    g.saveGState()
                    g.translateBy(x: p.x, y: p.y)
                    g.rotate(by: .random(in: 0..<(.pi)))
                    let len = CGFloat.random(in: 6...9)
                    let r = CGRect(x: -len / 2, y: -1.4, width: len, height: 2.8)
                    g.addPath(CGPath(roundedRect: r, cornerWidth: 1.4, cornerHeight: 1.4, transform: nil))
                    g.setFillColor(hues.randomElement()!.withAlphaComponent(0.9).cgColor)
                    g.fillPath()
                    g.restoreGState()
                }
            }

            // 3) Kristal yüzeyleri (merkezden köşelere üçgen faset)
            let tones: [(UIColor, CGFloat)] = [(.white, 0.07), (.black, 0.025), (.white, 0.03), (.black, 0.045), (.white, 0.05)]
            for i in pts.indices {
                let a = pts[i], b = pts[(i + 1) % pts.count]
                let tri = CGMutablePath()
                tri.move(to: cm); tri.addLine(to: a); tri.addLine(to: b); tri.closeSubpath()
                let t = tones[i % tones.count]
                g.addPath(tri)
                g.setFillColor(t.0.withAlphaComponent(t.1).cgColor)
                g.fillPath()
                g.addPath(tri)
                g.setStrokeColor(UIColor.white.withAlphaComponent(0.05).cgColor)
                g.setLineWidth(1)
                g.strokePath()
            }

            // 4) İç parıltı (kenarlardan içeri taşan ışık)
            g.saveGState()
            let frame = CGMutablePath()
            frame.addRect(bbox.insetBy(dx: -80, dy: -80))
            frame.addPath(path)
            g.setShadow(offset: .zero, blur: 18, color: UIColor.white.withAlphaComponent(0.8).cgColor)
            g.setFillColor(UIColor.white.cgColor)
            g.addPath(frame)
            g.fillPath(using: .evenOdd)
            g.restoreGState()

            // 5) Üst yansıma
            g.saveGState()
            g.clip(to: CGRect(x: bbox.minX, y: bbox.minY, width: bbox.width, height: bbox.height * 0.5))
            let gloss = CGGradient(colorsSpace: cs,
                                   colors: [UIColor.white.withAlphaComponent(0.42).cgColor, UIColor.white.withAlphaComponent(0).cgColor] as CFArray,
                                   locations: [0, 1])!
            g.drawLinearGradient(gloss, start: CGPoint(x: 0, y: bbox.minY), end: CGPoint(x: 0, y: bbox.minY + bbox.height * 0.5), options: [])
            g.restoreGState()

            // 6) Çapraz ışık çizgisi
            g.saveGState()
            g.setStrokeColor(UIColor.white.withAlphaComponent(0.22).cgColor)
            g.setLineWidth(max(3, bbox.width * 0.025))
            g.setLineCap(.round)
            let sx = bbox.minX + bbox.width * 0.2, sy = bbox.minY + bbox.height * 0.3
            g.move(to: CGPoint(x: sx, y: sy + bbox.height * 0.22))
            g.addLine(to: CGPoint(x: sx + bbox.width * 0.18, y: sy))
            g.strokePath()
            g.restoreGState()

            g.restoreGState()

            // 7) Parlak kenar
            g.addPath(path)
            g.setStrokeColor(UIColor.white.withAlphaComponent(0.95).cgColor)
            g.setLineWidth(2.4)
            g.setLineJoin(.round)
            g.strokePath()
        }
        let tex = SKTexture(image: img)
        tex.filteringMode = .linear
        let anchor = CGPoint(x: (c.x - minX + pad) / size.width, y: (c.y - minY + pad) / size.height)
        return (tex, size, anchor)
    }

    /// Kesilemeyen koyu cam çekirdek.
    /// `candy`: Pamuk Şeker setinde koyu ahududu şeker topu.
    static func core(radius: CGFloat, candy: Bool = false) -> (SKTexture, CGSize) {
        let pad: CGFloat = 10
        let d = radius * 2 + pad * 2
        let size = CGSize(width: d, height: d)
        let cs = CGColorSpaceCreateDeviceRGB()
        let img = UIGraphicsImageRenderer(size: size, format: format()).image { r in
            let g = r.cgContext
            let rect = CGRect(x: pad, y: pad, width: radius * 2, height: radius * 2)

            g.saveGState()
            g.setShadow(offset: .zero, blur: 8, color: UIColor.white.withAlphaComponent(0.5).cgColor)
            g.setFillColor((candy ? UIColor(120, 30, 84) : UIColor(30, 34, 84)).cgColor)
            g.fillEllipse(in: rect)
            g.restoreGState()

            g.saveGState()
            g.addEllipse(in: rect)
            g.clip()
            let grad = CGGradient(colorsSpace: cs,
                                  colors: (candy ? [UIColor(236, 104, 168).cgColor, UIColor(150, 36, 104).cgColor, UIColor(96, 20, 66).cgColor]
                                                 : [UIColor(96, 108, 196).cgColor, UIColor(34, 38, 90).cgColor, UIColor(20, 22, 58).cgColor]) as CFArray,
                                  locations: [0, 0.6, 1])!
            g.drawRadialGradient(grad, startCenter: CGPoint(x: rect.midX - radius * 0.3, y: rect.midY - radius * 0.35),
                                 startRadius: 0, endCenter: CGPoint(x: rect.midX, y: rect.midY), endRadius: radius, options: [.drawsAfterEndLocation])
            // yansıma
            g.setFillColor(UIColor.white.withAlphaComponent(0.45).cgColor)
            g.fillEllipse(in: CGRect(x: rect.minX + radius * 0.35, y: rect.minY + radius * 0.2, width: radius * 0.7, height: radius * 0.42))
            g.restoreGState()

            g.setStrokeColor(UIColor.white.withAlphaComponent(0.85).cgColor)
            g.setLineWidth(2)
            g.strokeEllipse(in: rect.insetBy(dx: 1, dy: 1))
            g.setStrokeColor(UIColor.white.withAlphaComponent(0.3).cgColor)
            g.setLineWidth(1.5)
            g.strokeEllipse(in: rect.insetBy(dx: radius * 0.45, dy: radius * 0.45))
        }
        let tex = SKTexture(image: img)
        tex.filteringMode = .linear
        return (tex, size)
    }

    /// İpucu için ışık çizgisi: uçlara doğru sönen, altın→beyaz gradyanlı, parıltılı çizgi.
    static func hintLine(length: CGFloat) -> (SKTexture, CGSize) {
        let pad: CGFloat = 34
        let size = CGSize(width: length, height: pad * 2)
        let cs = CGColorSpaceCreateDeviceRGB()
        let img = UIGraphicsImageRenderer(size: size, format: format()).image { r in
            let g = r.cgContext
            let y = size.height / 2
            let line = CGMutablePath()
            line.move(to: CGPoint(x: 0, y: y)); line.addLine(to: CGPoint(x: length, y: y))

            // 1) geniş yumuşak parıltı
            g.saveGState()
            g.setShadow(offset: .zero, blur: 26, color: UIColor(255, 200, 90, a: 0.9).cgColor)
            g.setStrokeColor(UIColor(255, 214, 120, a: 0.55).cgColor)
            g.setLineWidth(7)
            g.setLineCap(.round)
            g.addPath(line); g.strokePath()
            g.restoreGState()

            // 2) gradyanlı gövde (uçlar altın, orta beyaz)
            g.saveGState()
            g.addPath(line)
            g.setLineWidth(8)
            g.replacePathWithStrokedPath()
            g.clip()
            let body = CGGradient(colorsSpace: cs,
                                  colors: [UIColor(255, 190, 80).cgColor, UIColor(255, 236, 160).cgColor,
                                           UIColor(255, 255, 255).cgColor, UIColor(255, 236, 160).cgColor,
                                           UIColor(255, 190, 80).cgColor] as CFArray,
                                  locations: [0, 0.25, 0.5, 0.75, 1])!
            g.drawLinearGradient(body, start: CGPoint(x: 0, y: 0), end: CGPoint(x: length, y: 0), options: [])
            g.restoreGState()

            // 3) ince parlak çekirdek
            g.saveGState()
            g.setStrokeColor(UIColor.white.cgColor)
            g.setLineWidth(3)
            g.setLineCap(.round)
            g.addPath(line); g.strokePath()
            g.restoreGState()

            // 4) uçlara doğru sönme
            g.saveGState()
            g.setBlendMode(.destinationIn)
            let fade = CGGradient(colorsSpace: cs,
                                  colors: [UIColor(white: 1, alpha: 0).cgColor, UIColor(white: 1, alpha: 1).cgColor,
                                           UIColor(white: 1, alpha: 1).cgColor, UIColor(white: 1, alpha: 0).cgColor] as CFArray,
                                  locations: [0, 0.2, 0.8, 1])!
            g.drawLinearGradient(fade, start: CGPoint(x: 0, y: 0), end: CGPoint(x: length, y: 0), options: [])
            g.restoreGState()
        }
        let tex = SKTexture(image: img)
        tex.filteringMode = .linear
        return (tex, size)
    }

    /// Çizgi üzerinde akan küçük ışık topu.
    static func glowDot(radius: CGFloat) -> (SKTexture, CGSize) {
        let d = radius * 2
        let size = CGSize(width: d, height: d)
        let img = UIGraphicsImageRenderer(size: size, format: format()).image { r in
            let g = r.cgContext
            let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                  colors: [UIColor.white.cgColor, UIColor(255, 236, 160, a: 0.6).cgColor, UIColor(255, 200, 90, a: 0).cgColor] as CFArray,
                                  locations: [0, 0.3, 1])!
            g.drawRadialGradient(grad, startCenter: CGPoint(x: radius, y: radius), startRadius: 0,
                                 endCenter: CGPoint(x: radius, y: radius), endRadius: radius, options: [])
        }
        let tex = SKTexture(image: img)
        tex.filteringMode = .linear
        return (tex, size)
    }
}
