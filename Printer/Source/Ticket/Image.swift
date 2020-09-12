/*=================
    Image.swift
    Ticket

    Created by gix on 2019/6/30.
    Copyright © 2019 gix. All rights reserved.
=================*/

import Foundation

public protocol Image {
    var ticketImage: CGImage { get }
}

extension Image {
    var ticketData: Data? {
        let width = ticketImage.width
        let height = ticketImage.height
        
        if let grayData = convertImageToGray(ticketImage) {
            // get binary data
            if let binaryImageData = format_K_threshold(orgpixels: grayData, xsize: width, ysize: height) {
                // each line prepare for printer
                let data = eachLinePixToGSV0Cmd(src: binaryImageData, nWidth: width, nHeight: height, nMode: 0)
                return Data(bytes: data, count: data.count)
            }
        }
        
        return nil
    }
    
    /*================
        Convert image to gray
     ===============*/
    private func convertImageToGray(_ inputCGImage: CGImage) -> [UInt8]? {
        let kRed: Int = 1
        let kGreen: Int = 2
        let kBlue: Int = 4
        let colors: Int = kGreen | kBlue | kRed
        
        let colorSpace       = CGColorSpaceCreateDeviceRGB()
        let width            = inputCGImage.width
        let height           = inputCGImage.height
        let bytesPerPixel    = 4
        let bitsPerComponent = 8
        let bytesPerRow      = bytesPerPixel * width
        let bitmapInfo       = RGBA32.bitmapInfo
        
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: bitsPerComponent, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo) else {
            print("unable to create context")
            return nil
        }
        context.draw(inputCGImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        guard let buffer = context.data else {
            print("unable to get context data")
            return nil
        }
        
        var m_imageData = [UInt8]()
        let pixelBuffer = buffer.bindMemory(to: RGBA32.self, capacity: width * height)
        
        for row in 0 ..< Int(height) {
            for column in 0 ..< Int(width) {
                let offset = row * width + column
                var rgbPixel = pixelBuffer[offset]
                var sum: UInt32 = 0
                var count: UInt32 = 0
                
                // ignoring transperent or light color
                if rgbPixel == .clear || rgbPixel.color < 100 {
                    rgbPixel = .white
                }
                
                if colors & kRed != 0 {
                    sum += (rgbPixel.color >> 24) & 255
                    count += 1
                }
                if colors & kGreen != 0 {
                    sum += (rgbPixel.color >> 16) & 255
                    count += 1
                }
                if colors & kBlue != 0 {
                    sum += (rgbPixel.color >> 8) & 255
                    count += 1
                }
                m_imageData.append(UInt8(sum / count))
            }
        }
        
        return m_imageData
    }
    
    /*================
        Format K threshold
     ===============*/
    private func format_K_threshold(orgpixels: [UInt8], xsize: Int, ysize: Int) -> [UInt8]? {
        var despixels = [UInt8]()
        var graytotal: Int = 0
        var k: Int = 0
        
        var gray: Int
        for _ in 0..<ysize {
            for _ in 0..<xsize {
                gray = Int(orgpixels[k]) & 255
                graytotal += gray
                k += 1
            }
        }
        
        let grayave: Int = graytotal / ysize / xsize
        k = 0
        
        for _ in 0..<ysize {
            for _ in 0..<xsize {
                gray = Int(orgpixels[k]) & 255
                if gray > grayave {
                    despixels.append(UInt8(0))
                } else {
                    despixels.append(UInt8(1))
                }
                k += 1
            }
        }
        return despixels
    }
    
    /*===============
        Convert raster image GS V 0 command
     ==============*/
    private func eachLinePixToGSV0Cmd(src: [UInt8], nWidth: Int, nHeight: Int, nMode: Int) -> [UInt8] {
        var data = [[UInt8]]()
        
        let p0 = [0, 0x80]
        let p1 = [0, 0x40]
        let p2 = [0, 0x20]
        let p3 = [0, 0x10]
        let p4 = [0, 0x08]
        let p5 = [0, 0x04]
        let p6 = [0, 0x02]
        
        let nBytesPerLine: Int = (nWidth + 7) / 8
        let dotsPerHeight: Int = (nHeight + 23) / 24
        
        for i in 0..<dotsPerHeight {
            var header: [UInt8] = ESC_POSCommand.beginPrintImage(xl: UInt8(nBytesPerLine % 0xff), xH: UInt8(nBytesPerLine / 0xff), yl: UInt8(24), yH: UInt8(0)).rawValue
            var bytesPerLine: [UInt8] = [UInt8]()
            
            //  Case: bottom of image
            if i == dotsPerHeight - 1 {
                //  Case: complete with 24 dots
                if nHeight % 24 == 0 {
                    var byte: UInt8 = 0
                    var k = 0
                    
                    for j in 0..<nBytesPerLine * 24 * 8 {
                        print(i * nBytesPerLine * 24 * 8 + j)
                        switch k {
                        case 0:
                            byte += UInt8(p0[Int(src[i * nBytesPerLine * 24 * 8 + j])])
                        case 1:
                            byte += UInt8(p1[Int(src[i * nBytesPerLine * 24 * 8 + j])])
                        case 2:
                            byte += UInt8(p2[Int(src[i * nBytesPerLine * 24 * 8 + j])])
                        case 3:
                            byte += UInt8(p3[Int(src[i * nBytesPerLine * 24 * 8 + j])])
                        case 4:
                            byte += UInt8(p4[Int(src[i * nBytesPerLine * 24 * 8 + j])])
                        case 5:
                            byte += UInt8(p5[Int(src[i * nBytesPerLine * 24 * 8 + j])])
                        case 6:
                            byte += UInt8(p6[Int(src[i * nBytesPerLine * 24 * 8 + j])])
                        default:
                            byte += UInt8(src[i * nBytesPerLine * 24 * 8 + j])
                        }
                        
                        if (k == 7) {
                            bytesPerLine.append(byte)
                            
                            k = 0
                            byte = 0
                        }
                        else {
                            k += 1
                        }
                    }
                }
                //  Case: complete with less than 24 dots
                else {
                    header[6] = UInt8(nHeight % 24)
                    
                    var byte: UInt8 = 0
                    var k = 0
                    
                    for j in 0..<nBytesPerLine * (nHeight % 24) * 8 {
                        print(i * nBytesPerLine * 24 * 8 + j)
                        switch k {
                        case 0:
                            byte += UInt8(p0[Int(src[i * nBytesPerLine * 24 * 8 + j])])
                        case 1:
                            byte += UInt8(p1[Int(src[i * nBytesPerLine * 24 * 8 + j])])
                        case 2:
                            byte += UInt8(p2[Int(src[i * nBytesPerLine * 24 * 8 + j])])
                        case 3:
                            byte += UInt8(p3[Int(src[i * nBytesPerLine * 24 * 8 + j])])
                        case 4:
                            byte += UInt8(p4[Int(src[i * nBytesPerLine * 24 * 8 + j])])
                        case 5:
                            byte += UInt8(p5[Int(src[i * nBytesPerLine * 24 * 8 + j])])
                        case 6:
                            byte += UInt8(p6[Int(src[i * nBytesPerLine * 24 * 8 + j])])
                        default:
                            byte += UInt8(src[i * nBytesPerLine * 24 * 8 + j])
                        }
                        
                        if (k == 7) {
                            bytesPerLine.append(byte)
                            
                            k = 0
                            byte = 0
                        }
                        else {
                            k += 1
                        }
                    }
                }
            }
            //  Case: other
            else {
                var byte: UInt8 = 0
                var k = 0
                
                for j in 0..<nBytesPerLine * 24 * 8 {
                    print(i * nBytesPerLine * 24 * 8 + j)
                    print(src[i * nBytesPerLine * 24 * 8 + j])
                    
                    switch k {
                    case 0:
                        byte += UInt8(p0[Int(src[i * nBytesPerLine * 24 * 8 + j])])
                    case 1:
                        byte += UInt8(p1[Int(src[i * nBytesPerLine * 24 * 8 + j])])
                    case 2:
                        byte += UInt8(p2[Int(src[i * nBytesPerLine * 24 * 8 + j])])
                    case 3:
                        byte += UInt8(p3[Int(src[i * nBytesPerLine * 24 * 8 + j])])
                    case 4:
                        byte += UInt8(p4[Int(src[i * nBytesPerLine * 24 * 8 + j])])
                    case 5:
                        byte += UInt8(p5[Int(src[i * nBytesPerLine * 24 * 8 + j])])
                    case 6:
                        byte += UInt8(p6[Int(src[i * nBytesPerLine * 24 * 8 + j])])
                    default:
                        byte += UInt8(src[i * nBytesPerLine * 24 * 8 + j])
                    }
                    
                    if (k == 7) {
                        bytesPerLine.append(byte)
                        
                        k = 0
                        byte = 0
                    }
                    else {
                        k += 1
                    }
                }
            }
            
            data.append(header)
            data.append(bytesPerLine)
        }
        
        let rdata: [UInt8] = data.flatMap { $0 }
        return rdata
    }
    
    /*===============
        Convert raster image GS (L command
     ==============*/
    private func pixToGSLCmd(src: [UInt8], nWidth: Int, nHeight: Int, nMode: Int) -> [UInt8] {
        var data = [UInt8]()
        var header = [UInt8]()
        var header2 = [UInt8]()
    
        let p0 = [0, 0x80]
        let p1 = [0, 0x40]
        let p2 = [0, 0x20]
        let p3 = [0, 0x10]
        let p4 = [0, 0x08]
        let p5 = [0, 0x04]
        let p6 = [0, 0x02]
        
        //  Build header
        let paramSize: Int = (src.count / 8) + 10
        let pL: UInt8 = UInt8(paramSize & 0xff)
        let pH: UInt8 = UInt8((paramSize & 0xff00) >> 8)
        header.append(29)
        header.append(40)
        header.append(76)
        header.append(pL)
        header.append(pH)
        header.append(48)
        header.append(112)
        header.append(48)
        header.append(1)
        header.append(1)
        header.append(49)
        
        let horizontalBits: Int = nWidth;
        let xL: UInt8 = UInt8(horizontalBits & 0xff);
        let xH: UInt8 = UInt8((horizontalBits & 0xff00) >> 8)
        
        let verticalBits: Int = nHeight
        let yL: UInt8 = UInt8(verticalBits & 0xff)
        let yH: UInt8 = UInt8((verticalBits & 0xff00) >> 8)
        
        header.append(xL)
        header.append(xH)
        header.append(yL)
        header.append(yH)
        
        var k: Int = 0
        var byte: UInt8 = 0
        for bit in src {
            switch k {
            case 0:
                byte += UInt8(p0[Int(bit)])
            case 1:
                byte += UInt8(p1[Int(bit)])
            case 2:
                byte += UInt8(p2[Int(bit)])
            case 3:
                byte += UInt8(p3[Int(bit)])
            case 4:
                byte += UInt8(p4[Int(bit)])
            case 5:
                byte += UInt8(p5[Int(bit)])
            case 6:
                byte += UInt8(p6[Int(bit)])
            default:
                byte += UInt8(bit)
            }
            
            if (k == 7) {
                data.append(byte)
                
                k = 0
                byte = 0
            }
            else {
                k += 1
            }
        }
        
        header2.append(29)
        header2.append(40)
        header2.append(76)
        header2.append(2)
        header2.append(0)
        header2.append(48)
        header2.append(50)
        
        var d: [UInt8] = [UInt8]()
        d.append(contentsOf: header)
        d.append(contentsOf: data)
        d.append(contentsOf: header2)
        
        return d
    }
    
    /*===============
        Convert raster image ESC * command
     ==============*/
    private func eachLinePixToESStarCmd(src: [UInt8], nWidth: Int, nHeight: Int, nMode: Int) -> [UInt8] {
        var data: [UInt8] = [27, 42, 0, UInt8(nWidth), UInt8(nWidth >> 8)]
        let dotHeight: Int = Int((nHeight + 23) / 24)
        
        for i in 0..<dotHeight {
            var rowData: [[UInt8]] = [[UInt8]](repeating: [UInt8](), count: nWidth)
            
            for j in 0..<nWidth {
                rowData[j].append((i * nWidth + j) < src.count ? src[i * nWidth + j] : 0)
            }
        }
        
        return data
    }
}

private struct RGBA32: Equatable {
    var color: UInt32
    
    var redComponent: UInt8 {
        return UInt8((color >> 24) & 255)
    }
    
    var greenComponent: UInt8 {
        return UInt8((color >> 16) & 255)
    }
    
    var blueComponent: UInt8 {
        return UInt8((color >> 8) & 255)
    }
    
    var alphaComponent: UInt8 {
        return UInt8((color >> 0) & 255)
    }
    
    init(red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8) {
        let red   = UInt32(red)
        let green = UInt32(green)
        let blue  = UInt32(blue)
        let alpha = UInt32(alpha)
        color = (red << 24) | (green << 16) | (blue << 8) | (alpha << 0)
    }
    
    static let red     = RGBA32(red: 255, green: 0,   blue: 0,   alpha: 255)
    static let green   = RGBA32(red: 0,   green: 255, blue: 0,   alpha: 255)
    static let blue    = RGBA32(red: 0,   green: 0,   blue: 255, alpha: 255)
    static let white   = RGBA32(red: 255, green: 255, blue: 255, alpha: 255)
    static let black   = RGBA32(red: 0,   green: 0,   blue: 0,   alpha: 255)
    static let magenta = RGBA32(red: 255, green: 0,   blue: 255, alpha: 255)
    static let yellow  = RGBA32(red: 255, green: 255, blue: 0,   alpha: 255)
    static let cyan    = RGBA32(red: 0,   green: 255, blue: 255, alpha: 255)
    static let clear   = RGBA32(red: 0,   green: 0,   blue: 0,   alpha: 0)
    
    static let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
    
    static func ==(lhs: RGBA32, rhs: RGBA32) -> Bool {
        return lhs.color == rhs.color
    }
}

extension UIImage: Image {
    public var ticketImage: CGImage {
        guard let image = cgImage else {
            fatalError("can't get cgimage ref.")
        }
        return image
    }
}

extension UIView: Image {
    public var ticketImage: CGImage {
        if #available(iOS 10.0, *) {
            let renderer = UIGraphicsImageRenderer(bounds: bounds)
            return renderer.image { rendererContext in
                layer.render(in: rendererContext.cgContext)
            }.ticketImage
        } else {
            UIGraphicsBeginImageContext(frame.size)
            defer {
                UIGraphicsEndImageContext()
            }
            layer.render(in: UIGraphicsGetCurrentContext()!)
            guard let image = UIGraphicsGetImageFromCurrentImageContext() else {
                fatalError("UIGraphics Get Image Failed.")
            }
            return image.ticketImage
        }
    }
}
