import AppKit
import ImageIO
let root=URL(fileURLWithPath:CommandLine.arguments[1])
let rows=try JSONSerialization.jsonObject(with:Data(contentsOf:root.appendingPathComponent("color-backgrounds.json"))) as! [[String:Any]]
for row in rows {
 guard let values=row["Color components"] as? [Double], let file=row["output"] as? String else {continue}
 let csName=(row["Colorspace"] as? String ?? "srgb").lowercased()
 let space:CGColorSpace = values.count==2 ? CGColorSpace(name:CGColorSpace.genericGrayGamma2_2)! : CGColorSpace(name:csName.contains("p3") ? CGColorSpace.displayP3 : CGColorSpace.sRGB)!
 guard let color=CGColor(colorSpace:space,components:values.map{CGFloat($0)}), let ctx=CGContext(data:nil,width:1088,height:1088,bitsPerComponent:8,bytesPerRow:0,space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue) else {fatalError("Bad color")}
 ctx.setFillColor(color);ctx.fill(CGRect(x:0,y:0,width:1088,height:1088))
 let target=root.appendingPathComponent(file);try FileManager.default.createDirectory(at:target.deletingLastPathComponent(),withIntermediateDirectories:true)
 let dest=CGImageDestinationCreateWithURL(target as CFURL,"public.png" as CFString,1,nil)!;CGImageDestinationAddImage(dest,ctx.makeImage()!,nil);guard CGImageDestinationFinalize(dest) else {fatalError("Write failed")}
}
print("Rendered \(rows.count) source color backgrounds")
// A contact sheet of the full-resolution Home Modular designs, in light/dark pairs.
let folder=root.appendingPathComponent("Images/Home-Modular")
let files=try FileManager.default.contentsOfDirectory(at:folder,includingPropertiesForKeys:nil).filter{$0.pathExtension=="png"}.sorted{$0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending}
let width=1200,cellW=240,cellH=264,height=((files.count+4)/5)*cellH+64
let bitmap=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:width,pixelsHigh:height,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current=NSGraphicsContext(bitmapImageRep:bitmap)
NSColor(calibratedWhite:0.1,alpha:1).setFill();NSRect(x:0,y:0,width:width,height:height).fill()
("HomeView · 20 designs · Light & Dark" as NSString).draw(at:NSPoint(x:24,y:height-43),withAttributes:[.font:NSFont.systemFont(ofSize:23,weight:.semibold),.foregroundColor:NSColor.white])
for (i,file) in files.enumerated(){
 let x=(i%5)*cellW+12,y=height-64-(i/5+1)*cellH+32
 NSImage(contentsOf:file)!.draw(in:NSRect(x:x,y:y,width:216,height:216))
 let label=file.deletingPathExtension().lastPathComponent.replacingOccurrences(of:"--UIAppearanceDark",with:" · dark").replacingOccurrences(of:"--Light",with:" · light")
 (label as NSString).draw(at:NSPoint(x:x,y:y-23),withAttributes:[.font:NSFont.systemFont(ofSize:13),.foregroundColor:NSColor.white])
}
NSGraphicsContext.restoreGraphicsState();try bitmap.representation(using:.png,properties:[:])!.write(to:root.appendingPathComponent("Wallpaper Preview.png"))
