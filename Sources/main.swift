import AppKit
import SwiftUI
import Combine

let actionNames = ["蹦跳低头", "左右张望", "转身扭扭", "开心晃动", "歪头挠挠", "躺下打滚", "气鼓鼓", "开怀大笑"]
struct Todo: Codable, Identifiable { var id=UUID(); var text:String; var done=false }
final class PetModel: ObservableObject {
 @Published var action=1
 @Published var paused=false
 @Published var autoPlay=false
 @Published var minutes=25
 @Published var remaining=25*60
 @Published var running=false
 @Published var completed=UserDefaults.standard.integer(forKey:"completed")
 @Published var todos:[Todo]=[] { didSet { if let data=try? JSONEncoder().encode(todos){UserDefaults.standard.set(data,forKey:"todos")} } }
 var deadline:Date?
 var onAction:((Int)->Void)?
 var onFinished:(()->Void)?
 var clock:Timer?
 init(){
  if let d=UserDefaults.standard.data(forKey:"todos"),let t=try? JSONDecoder().decode([Todo].self,from:d){todos=t}
  clock=Timer.scheduledTimer(withTimeInterval:0.5,repeats:true){[weak self] _ in self?.tick()}
 }
 func tick(){guard running,let d=deadline else{return};remaining=max(0,Int(ceil(d.timeIntervalSinceNow)));if remaining==0{running=false;deadline=nil;completed+=1;UserDefaults.standard.set(completed,forKey:"completed");onFinished?()}}
 func select(_ i:Int){action=i;paused=false;onAction?(i)}
 func start(){if remaining<=0{remaining=minutes*60};deadline=Date().addingTimeInterval(Double(remaining));running=true}
 func pause(){tick();running=false;deadline=nil}
 func reset(){running=false;deadline=nil;remaining=minutes*60}
 var time:String{String(format:"%02d:%02d",remaining/60,remaining%60)}
 func add(_ text:String){let t=text.trimmingCharacters(in:.whitespacesAndNewlines);if !t.isEmpty {todos.append(Todo(text:t))}}
}
final class PetPanel:NSPanel {override var canBecomeKey:Bool{false};override var canBecomeMain:Bool{false}}
final class PetView:NSView {
 weak var controller:PetController?
 var frameImage:NSImage?
 var bitmap:NSBitmapImageRep?
 var bubble=""
 var bubbleUntil=Date.distantPast
 var downPoint=NSPoint.zero, downOrigin=NSPoint.zero
 var dragging=false
 override var isOpaque:Bool{false}
 override var acceptsFirstResponder:Bool{true}
 override func draw(_ dirtyRect:NSRect){
  NSColor.clear.setFill();bounds.fill(using:.copy)
  frameImage?.draw(in:NSRect(x:0,y:0,width:bounds.width,height:bounds.width),from:.zero,operation:.sourceOver,fraction:1)
  if Date()<bubbleUntil {
   let para=NSMutableParagraphStyle();para.alignment = .center
   let rect=NSRect(x:4,y:bounds.width+2,width:bounds.width-8,height:24)
   NSColor(calibratedRed:1,green:0.97,blue:0.86,alpha:0.96).setFill();NSBezierPath(roundedRect:rect,xRadius:12,yRadius:12).fill()
   (bubble as NSString).draw(in:rect.insetBy(dx:5,dy:4),withAttributes:[.font:NSFont.systemFont(ofSize:11,weight:.medium),.foregroundColor:NSColor(calibratedWhite:0.22,alpha:1),.paragraphStyle:para])
  }
 }
 func isSolid(_ point:NSPoint)->Bool{
  if Date()<bubbleUntil && point.y>bounds.width && bounds.contains(point){return true}
  guard point.x>=0,point.x<bounds.width,point.y>=0,point.y<bounds.width,let b=bitmap else{return false}
  let x=min(b.pixelsWide-1,Int(point.x/bounds.width*Double(b.pixelsWide)))
  let y=min(b.pixelsHigh-1,Int((1-point.y/bounds.width)*Double(b.pixelsHigh)))
  return (b.colorAt(x:x,y:y)?.alphaComponent ?? 0)>0.12
 }
 override func mouseDown(with event:NSEvent){downPoint=NSEvent.mouseLocation;downOrigin=window?.frame.origin ?? .zero;dragging=true;controller?.holding=true}
 override func mouseDragged(with event:NSEvent){let p=NSEvent.mouseLocation;window?.setFrameOrigin(NSPoint(x:downOrigin.x+p.x-downPoint.x,y:downOrigin.y+p.y-downPoint.y))}
 override func mouseUp(with event:NSEvent){
  let p=NSEvent.mouseLocation;dragging=false;controller?.holding=false;controller?.constrainAndSave()
  if hypot(p.x-downPoint.x,p.y-downPoint.y)<5 {
   if event.clickCount>=2{controller?.showCompanion()}else{controller?.nextAction()}
  }
 }
 override func rightMouseDown(with event:NSEvent){guard let c=controller else{return};c.holding=true;NSMenu.popUpContextMenu(c.makeMenu(),with:event,for:self);c.holding=false}
 override func scrollWheel(with event:NSEvent){if abs(event.scrollingDeltaY)>0.5{controller?.resize(by:event.scrollingDeltaY>0 ? 10 : -10)}}
}
final class PetController:NSObject,NSApplicationDelegate {
 let model=PetModel()
 var panel:PetPanel!,pet:PetView!,status:NSStatusItem!,companion:NSWindow?
 var timer:Timer?
 var current=1,lastFrame = -1
 var epoch=Date(), pausedAt:Date?
 var holding=false
 var pinned=true
 var size:CGFloat=200
 let cache=NSCache<NSString,NSImage>()
 let resources=Bundle.main.resourceURL!.appendingPathComponent("Frames")
 func applicationDidFinishLaunching(_ notification:Notification){
  NSApp.setActivationPolicy(.accessory)
  cache.countLimit=110
  let saved=UserDefaults.standard.double(forKey:"size");if saved>=120 && saved<=360{size=saved}
  panel=PetPanel(contentRect:NSRect(x:0,y:0,width:size,height:size+28),styleMask:[.borderless,.nonactivatingPanel],backing:.buffered,defer:false)
  panel.title="奶蛋桌宠 · 开源示例";panel.isOpaque=false;panel.backgroundColor = .clear;panel.hasShadow=false;panel.level = .floating
  panel.collectionBehavior=[.canJoinAllSpaces,.fullScreenAuxiliary,.stationary];panel.hidesOnDeactivate=false;panel.isReleasedWhenClosed=false
  pet=PetView(frame:NSRect(x:0,y:0,width:size,height:size+28));panel.contentView=pet;pet.controller=self
  pet.setAccessibilityElement(true);pet.setAccessibilityLabel("奶蛋桌宠，拖动移动，单击切动作，右键菜单，双击打开陪伴面板")
  status=NSStatusBar.system.statusItem(withLength:NSStatusItem.variableLength);status.button?.title="🥚";status.button?.toolTip="奶蛋桌宠";status.menu=makeMenu()
  let appMenu=NSMenu();let root=NSMenuItem();let sub=NSMenu();sub.addItem(withTitle:"专注与待办…",action:#selector(showCompanion),keyEquivalent:"p").target=self;sub.addItem(withTitle:"退出奶蛋桌宠",action:#selector(quit),keyEquivalent:"q").target=self;root.submenu=sub;appMenu.addItem(root);let editRoot=NSMenuItem(title:"编辑",action:nil,keyEquivalent:"");let edit=NSMenu(title:"编辑")
  edit.addItem(withTitle:"剪切",action:Selector(("cut:")),keyEquivalent:"x")
  edit.addItem(withTitle:"复制",action:Selector(("copy:")),keyEquivalent:"c")
  edit.addItem(withTitle:"粘贴",action:Selector(("paste:")),keyEquivalent:"v")
  edit.addItem(withTitle:"全选",action:Selector(("selectAll:")),keyEquivalent:"a")
  editRoot.submenu=edit;appMenu.addItem(editRoot);NSApp.mainMenu=appMenu
  if UserDefaults.standard.object(forKey:"x") != nil {panel.setFrameOrigin(NSPoint(x:UserDefaults.standard.double(forKey:"x"),y:UserDefaults.standard.double(forKey:"y")));constrainAndSave()}else{resetPosition()}
  model.onAction={[weak self] i in self?.setAction(i)}
  model.onFinished={[weak self] in self?.model.select(7);self?.say("完成一轮，休息一下吧");self?.showCompanion()}
  setAction(1);panel.orderFrontRegardless();say("拖动我 · 右键打开菜单",duration:9)
  timer=Timer(timeInterval:1/24,repeats:true){[weak self] _ in self?.tick()};RunLoop.main.add(timer!,forMode:.common)
  if !UserDefaults.standard.bool(forKey:"welcomed"){showCompanion();UserDefaults.standard.set(true,forKey:"welcomed")}
 }
 func applicationShouldHandleReopen(_ sender:NSApplication,hasVisibleWindows flag:Bool)->Bool{showCompanion();return true}
 func frameURL(_ action:Int,_ index:Int)->URL{resources.appendingPathComponent(String(format:"clip-%02d/%03d.png",action+1,index))}
 // Optional user-owned PNG frames take precedence over the procedural demo.
 func image(_ action:Int,_ index:Int)->NSImage? {
  let key="\(action)-\(index)" as NSString
  if let cached=cache.object(forKey:key){return cached}
  let result=NSImage(contentsOf:frameURL(action,index)) ?? demoFrame(action,index)
  cache.setObject(result,forKey:key)
  return result
 }
 func setAction(_ i:Int){current=i;epoch=Date();pausedAt=nil;lastFrame = -1;cache.removeAllObjects();status.menu=makeMenu();updateFrame(0)}
 func updateFrame(_ n:Int){guard n != lastFrame,let im=image(current,n)else{return};pet.frameImage=im;pet.bitmap=im.representations.compactMap{$0 as? NSBitmapImageRep}.first ?? im.tiffRepresentation.flatMap{NSBitmapImageRep(data:$0)};lastFrame=n;pet.needsDisplay=true}
 func tick(){
  if model.paused {if pausedAt==nil{pausedAt=Date()}}else{
   if let p=pausedAt{epoch=epoch.addingTimeInterval(Date().timeIntervalSince(p));pausedAt=nil}
   let elapsed=Date().timeIntervalSince(epoch)
   if elapsed>=4 && model.autoPlay{model.select((current+1)%8)}
   else{updateFrame(Int(elapsed*24)%96)}
  }
  if !holding {
   let point=pet.convert(panel.convertPoint(fromScreen:NSEvent.mouseLocation),from:nil)
   panel.ignoresMouseEvents = !pet.isSolid(point)
  }
  pet.needsDisplay=true
 }
 func say(_ text:String,duration:Double=3){pet.bubble=text;pet.bubbleUntil=Date().addingTimeInterval(duration);pet.needsDisplay=true}
 func nextAction(){model.select((current+1)%8);say(actionNames[current])}
 func resize(by delta:CGFloat){size=min(360,max(120,size+delta));panel.setContentSize(NSSize(width:size,height:size+28));pet.frame=NSRect(x:0,y:0,width:size,height:size+28);UserDefaults.standard.set(size,forKey:"size");constrainAndSave()}
 func constrainAndSave(){
  let screens=NSScreen.screens;guard let screen=screens.first(where:{$0.visibleFrame.intersects(panel.frame)}) ?? NSScreen.main else{return}
  let r=screen.visibleFrame;var p=panel.frame.origin;p.x=min(max(p.x,r.minX),r.maxX-panel.frame.width);p.y=min(max(p.y,r.minY),r.maxY-panel.frame.height);panel.setFrameOrigin(p)
  UserDefaults.standard.set(Double(p.x),forKey:"x");UserDefaults.standard.set(Double(p.y),forKey:"y")
 }
 @objc func resetPosition(){guard let r=NSScreen.main?.visibleFrame else{return};panel.setFrameOrigin(NSPoint(x:r.maxX-size-30,y:r.minY+24));constrainAndSave()}
 @objc func choose(_ sender:NSMenuItem){model.select(sender.tag);say(actionNames[sender.tag])}
 @objc func togglePause(){model.paused.toggle();status.menu=makeMenu()}
 @objc func toggleAuto(){model.autoPlay.toggle();status.menu=makeMenu()}
 @objc func togglePin(){pinned.toggle();panel.level=pinned ? .floating : .normal;status.menu=makeMenu()}
 @objc func toggleVisible(){if panel.isVisible{panel.orderOut(nil)}else{panel.orderFrontRegardless()};status.menu=makeMenu()}
 @objc func smaller(){resize(by:-30)}
 @objc func larger(){resize(by:30)}
 @objc func quit(){NSApp.terminate(nil)}
 func makeMenu()->NSMenu{
  let m=NSMenu();let title=NSMenuItem(title:"奶蛋 · 开源示例版",action:nil,keyEquivalent:"");m.addItem(title);m.addItem(.separator())
  for (i,name) in actionNames.enumerated(){let item=NSMenuItem(title:name,action:#selector(choose(_:)),keyEquivalent:"");item.target=self;item.tag=i;item.state=current==i ? .on : .off;m.addItem(item)}
  m.addItem(.separator())
  func add(_ s:String,_ a:Selector,_ state:Bool?=nil){let it=NSMenuItem(title:s,action:a,keyEquivalent:"");it.target=self;if let b=state{it.state=b ? .on : .off};m.addItem(it)}
  add("依次播放全部动作",#selector(toggleAuto),model.autoPlay);add(model.paused ? "继续动作" : "暂停动作",#selector(togglePause));add("保持在最前面",#selector(togglePin),pinned)
  m.addItem(.separator());add("专注与待办…",#selector(showCompanion));add("放大",#selector(larger));add("缩小",#selector(smaller));add("回到屏幕右下角",#selector(resetPosition));add(panel?.isVisible == false ? "显示奶蛋" : "暂时隐藏",#selector(toggleVisible));m.addItem(.separator());add("退出奶蛋桌宠",#selector(quit));return m
 }
 @objc func showCompanion(){
  if companion==nil{
   let w=NSWindow(contentRect:NSRect(x:0,y:0,width:620,height:590),styleMask:[.titled,.closable,.miniaturizable],backing:.buffered,defer:false)
   w.title="奶蛋的陪伴小站";w.isReleasedWhenClosed=false;w.contentView=NSHostingView(rootView:CompanionView(model:model,controller:self));w.center();companion=w
  }
  NSApp.activate(ignoringOtherApps:true);companion?.makeKeyAndOrderFront(nil)
 }
}
struct CompanionView:View{
 @ObservedObject var model:PetModel
 let controller:PetController
 @State var newTodo=""
 let ink=Color(red:0.22,green:0.19,blue:0.13)
 let amber=Color(red:0.68,green:0.40,blue:0.10)
 var body:some View{
  VStack(alignment:.leading,spacing:18){
   HStack(spacing:16){
    if let img=controller.image(model.action,0){Image(nsImage:img).resizable().scaledToFit().frame(width:84,height:84)}
    VStack(alignment:.leading,spacing:5){Text("今天也陪着你").font(.system(size:26,weight:.bold,design:.rounded));Text("奶蛋桌宠 · 开源示例版").font(.subheadline).foregroundStyle(.secondary)}
    Spacer()
    Button(model.paused ? "继续动作" : "暂停动作"){controller.togglePause()}
   }
   LazyVGrid(columns:Array(repeating:GridItem(.flexible()),count:4),spacing:8){
    ForEach(0..<8,id:\.self){i in Button{model.select(i)}label:{Text(actionNames[i]).frame(maxWidth:.infinity).padding(.vertical,7).background(model.action==i ? Color(red:1,green:0.83,blue:0.35):Color.white.opacity(0.8)).clipShape(RoundedRectangle(cornerRadius:9))}.buttonStyle(.plain)}
   }
   HStack(alignment:.top,spacing:16){
    VStack(alignment:.leading,spacing:12){
     Label("专注一会儿",systemImage:"timer").font(.headline)
     Text(model.time).font(.system(size:43,weight:.medium,design:.rounded)).monospacedDigit()
     Picker("时长",selection:$model.minutes){ForEach([5,15,25,45,60],id:\.self){Text("\($0) 分钟").tag($0)}}.disabled(model.running).onChange(of:model.minutes){model.reset()}
     HStack{Button(model.running ? "暂停" : "开始"){if model.running{model.pause()}else{model.start()}}.buttonStyle(.borderedProminent).tint(amber);Button("重置"){model.reset()}}
     Text("已完成 \(model.completed) 轮专注").font(.caption).foregroundStyle(.secondary)
     Text("到时奶蛋会提醒你休息。\n关闭面板后，计时仍会继续。").font(.caption).foregroundStyle(.secondary)
    }.frame(width:210,alignment:.leading).padding(16).background(.white.opacity(0.8)).clipShape(RoundedRectangle(cornerRadius:16))
    VStack(alignment:.leading,spacing:12){
     Label("今天的小事",systemImage:"checklist").font(.headline)
     HStack{TextField("写下一件小事",text:$newTodo).onSubmit{add()};Button{add()}label:{Image(systemName:"plus")}.disabled(newTodo.trimmingCharacters(in:.whitespaces).isEmpty)}
     ScrollView{
      if model.todos.isEmpty {VStack(spacing:8){Image(systemName:"leaf").font(.title2);Text("慢慢来，一件一件完成。").font(.caption)}.foregroundStyle(.secondary).frame(maxWidth:.infinity).padding(.top,30)}
      LazyVStack(alignment:.leading,spacing:9){ForEach(model.todos){t in HStack(alignment:.top){Button{if let i=model.todos.firstIndex(where:{$0.id==t.id}){model.todos[i].done.toggle()}}label:{Image(systemName:t.done ? "checkmark.circle.fill":"circle").foregroundStyle(t.done ? Color.green:Color.secondary)}.buttonStyle(.plain);Text(t.text).strikethrough(t.done).foregroundStyle(t.done ? Color.secondary:ink);Spacer();Button{model.todos.removeAll{$0.id==t.id}}label:{Image(systemName:"xmark").font(.caption)}.buttonStyle(.plain).help("删除这条待办")}.padding(.vertical,3)}}
     }.frame(height:175)
     Text("只保存在这台 Mac 上").font(.caption2).foregroundStyle(.secondary)
    }.padding(16).frame(maxWidth:.infinity).background(.white.opacity(0.8)).clipShape(RoundedRectangle(cornerRadius:16))
   }
   HStack{Text("拖动移动 · 单击换动作 · 双击打开此面板 · 右键更多").font(.caption).foregroundStyle(.secondary);Spacer();Button("收起"){controller.companion?.orderOut(nil)}}
  }.padding(24).foregroundStyle(ink).background(Color(red:0.98,green:0.96,blue:0.90)).frame(width:620,height:590)
 }
 func add(){model.add(newTodo);newTodo=""}
}

// Original procedural demo: geometric egg, feet, face and a small teal sprout.
// No source video, extracted image, downloaded asset or generative API is used.
func demoFrame(_ action:Int,_ index:Int)->NSImage {
 let side=480
 let bitmap=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:side,pixelsHigh:side,
  bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
 NSGraphicsContext.saveGraphicsState()
 NSGraphicsContext.current=NSGraphicsContext(bitmapImageRep:bitmap)
 NSColor.clear.setFill();NSRect(x:0,y:0,width:side,height:side).fill(using:.copy)
 let phase=Double(index)/96 * 2 * Double.pi
 let wave=sin(phase)
 let transform=NSAffineTransform()
 transform.translateX(by:240,yBy:225 + (action == 0 ? abs(wave)*35 : wave*5))
 transform.rotate(byDegrees:action == 5 ? wave*65 : (action == 2 || action == 3 ? wave*14 : wave*4))
 transform.concat()
 func oval(_ rect:NSRect,_ color:NSColor){color.setFill();NSBezierPath(ovalIn:rect).fill()}
 let ink=NSColor(calibratedRed:0.16,green:0.23,blue:0.24,alpha:1)
 let cream=NSColor(calibratedRed:1,green:0.91,blue:0.65,alpha:1)
 let teal=NSColor(calibratedRed:0.22,green:0.57,blue:0.51,alpha:1)
 oval(NSRect(x:-88,y:-138,width:64,height:27),teal)
 oval(NSRect(x:24,y:-138,width:64,height:27),teal)
 let egg=NSBezierPath()
 egg.move(to:NSPoint(x:0,y:140))
 egg.curve(to:NSPoint(x:115,y:-50),controlPoint1:NSPoint(x:60,y:140),controlPoint2:NSPoint(x:115,y:10))
 egg.curve(to:NSPoint(x:-115,y:-50),controlPoint1:NSPoint(x:115,y:-155),controlPoint2:NSPoint(x:-115,y:-155))
 egg.curve(to:NSPoint(x:0,y:140),controlPoint1:NSPoint(x:-115,y:10),controlPoint2:NSPoint(x:-60,y:140))
 egg.close();cream.setFill();egg.fill();ink.setStroke();egg.lineWidth=6;egg.stroke()
 oval(NSRect(x:-4,y:132,width:38,height:20),teal)
 oval(NSRect(x:-30,y:137,width:30,height:18),teal)
 let gaze=action == 1 ? wave*12 : 0
 let blink=index % 96 >= 88 || action == 7
 for x:Double in [-37,37] {
  oval(NSRect(x:x+gaze-7,y:10,width:14,height:blink ? 4:20),ink)
 }
 let blush=NSColor(calibratedRed:0.96,green:0.57,blue:0.46,alpha:0.65)
 oval(NSRect(x:-72,y:-17,width:28,height:15),blush)
 oval(NSRect(x:44,y:-17,width:28,height:15),blush)
 if action == 6 {
  let brows=NSBezierPath();brows.move(to:NSPoint(x:-50,y:43));brows.line(to:NSPoint(x:-22,y:31));brows.move(to:NSPoint(x:22,y:31));brows.line(to:NSPoint(x:50,y:43));ink.setStroke();brows.lineWidth=5;brows.stroke()
 }
 let mouth=NSBezierPath();mouth.move(to:NSPoint(x:-19,y:-24));mouth.curve(to:NSPoint(x:19,y:-24),controlPoint1:NSPoint(x:-12,y:action == 7 ? -65:-42),controlPoint2:NSPoint(x:12,y:action == 7 ? -65:-42));ink.setStroke();mouth.lineWidth=5;mouth.stroke()
 if action == 4 {oval(NSRect(x:88,y:20+wave*15,width:24,height:35),teal)}
 NSGraphicsContext.restoreGraphicsState()
 let image=NSImage(size:NSSize(width:side,height:side));image.addRepresentation(bitmap);return image
}

let app=NSApplication.shared
let delegate=PetController()
app.delegate=delegate
app.run()
