import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'arcade_style.dart';
import 'game_engine.dart';
import 'game_platform.dart' as platform;

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override Widget build(BuildContext context)=>MaterialApp(debugShowCheckedModeBanner:false,
    title:'双频找不同 · 频率站',theme:arcadeTheme(),home:const DifferenceArcade());
}
class DifferenceArcade extends StatefulWidget {
  const DifferenceArcade({super.key});
  @override State<DifferenceArcade> createState()=>_DifferenceArcadeState();
}
class _DifferenceArcadeState extends State<DifferenceArcade> with SingleTickerProviderStateMixin,WidgetsBindingObserver {
  final FocusNode focus=FocusNode();
  final TransformationController transform=TransformationController();
  late Ticker ticker;
  Duration? previous;
  List<DifferenceLevel> levels=[];
  DifferenceEngine? game;
  String? error, imageError;
  int imageRevision=0;
  int index=0,unlocked=0,best=0;
  double? bestTime;
  bool sound=true,reduced=false,saved=true,keyboardCursor=false;
  double cursorX=.5,cursorY=.5,zoom=1;
  int second=-1;
  @override void initState(){
    super.initState();sound=platform.readValue('manager.arcade.diff.sound.v1')!='off';
    reduced=platform.readValue('manager.arcade.diff.motion.v1')=='reduce'||platform.systemReducedMotion();
    unlocked=(int.tryParse(platform.readValue('manager.arcade.diff.unlocked.v1')??'0')??0).clamp(0,9).toInt();
    ticker=createTicker(_tick)..start();WidgetsBinding.instance.addObserver(this);platform.watchSuspension(_pause);_load();
  }
  Future<void> _load() async {
    try{
      final raw=jsonDecode(await rootBundle.loadString('assets/images/frequency-levels.json')) as List;
      final data=raw.map((m)=>DifferenceLevel.fromJson(Map<String,dynamic>.from(m as Map))).toList();
      if(data.isEmpty)throw const FormatException('暂无关卡');
      if(!mounted)return;
      setState((){levels=data;error=null;_reset(0);});
    }catch(e){if(mounted)setState(()=>error='场景暂时没有加载成功。请联网后重试。');}
  }
  void _reset(int newIndex){imageError=null;index=newIndex;game=DifferenceEngine(levels[index]);previous=null;second=-1;zoom=1;transform.value=Matrix4.identity();
    cursorX=.5;cursorY=.5;keyboardCursor=false;best=int.tryParse(platform.readValue('manager.arcade.diff.best.$index.v1')??'0')??0;
    bestTime=double.tryParse(platform.readValue('manager.arcade.diff.time.$index.v1')??'');}
  void _retry([int? next]){setState(()=>_reset(next??index));focus.requestFocus();}
  void _tick(Duration now){final old=previous;previous=now;final g=game;if(g==null||old==null||g.status!=DifferenceStatus.playing)return;
    final status=g.status;g.advance((now-old).inMicroseconds/1000000);
    if(g.elapsed.floor()!=second||status!=g.status){second=g.elapsed.floor();setState((){});}
  }
  void _start(){setState((){game?.start();previous=null;});focus.requestFocus();if(sound)platform.playTone('tap');}
  void _pause(){if(!mounted||game?.status!=DifferenceStatus.playing)return;setState((){game!.pause();previous=null;});}
  void _resume(){setState((){game?.resume();previous=null;});focus.requestFocus();}
  void _record(){final g=game!;if(g.score>best){best=g.score;saved=platform.writeValue('manager.arcade.diff.best.$index.v1','$best');}
    if(g.hintsUsed==0&&(bestTime==null||g.elapsed<bestTime!)){bestTime=g.elapsed;saved=platform.writeValue('manager.arcade.diff.time.$index.v1','${g.elapsed}')&&saved;}
    if(index<levels.length-1){unlocked=max(unlocked,index+1);saved=platform.writeValue('manager.arcade.diff.unlocked.v1','$unlocked')&&saved;}}
  void _tap(double x,double y){final g=game;if(g==null)return;
    final result=g.tap(x,y);if(result==TapResult.ignored)return;
    if(sound&&(result==TapResult.found||result==TapResult.missed))platform.playTone(result==TapResult.found?'collect':'fail');
    if(g.status==DifferenceStatus.cleared){_record();if(sound)platform.playTone('win');}
    setState((){});focus.requestFocus();
  }
  void _hint(){if(game?.useHint()==true){setState((){});if(sound)platform.playTone('tap');}focus.requestFocus();}
  void _zoom(double value){zoom=value.clamp(1.0,3.0).toDouble();setState(()=>transform.value=Matrix4.diagonal3Values(zoom,zoom,1));focus.requestFocus();}
  @override void didChangeAppLifecycleState(AppLifecycleState state){if(state!=AppLifecycleState.resumed)_pause();}
  KeyEventResult _key(FocusNode _,KeyEvent event){
    if(event is! KeyDownEvent&&event is! KeyRepeatEvent)return KeyEventResult.ignored;
    final key=event.logicalKey; final g=game;
    if(g==null)return KeyEventResult.ignored;
    if(event is KeyDownEvent){
      if(key==LogicalKeyboardKey.escape||key==LogicalKeyboardKey.keyP){if(g.status==DifferenceStatus.paused){_resume();}else{_pause();}return KeyEventResult.handled;}
      if(key==LogicalKeyboardKey.enter&&g.status==DifferenceStatus.ready){_start();return KeyEventResult.handled;}
      if(key==LogicalKeyboardKey.keyR&&g.status==DifferenceStatus.cleared){_retry();return KeyEventResult.handled;}
      if(key==LogicalKeyboardKey.keyH){_hint();return KeyEventResult.handled;}
      if((key==LogicalKeyboardKey.enter||key==LogicalKeyboardKey.space)&&g.status==DifferenceStatus.playing){_tap(cursorX,cursorY);return KeyEventResult.handled;}
    }
    if(g.status!=DifferenceStatus.playing)return KeyEventResult.ignored;
    final step=HardwareKeyboard.instance.isShiftPressed ? .01 : .025;
    double dx=0,dy=0;
    if(key==LogicalKeyboardKey.arrowLeft)dx=-step;else if(key==LogicalKeyboardKey.arrowRight)dx=step;
    else if(key==LogicalKeyboardKey.arrowUp)dy=-step;else if(key==LogicalKeyboardKey.arrowDown)dy=step;else return KeyEventResult.ignored;
    setState((){keyboardCursor=true;cursorX=(cursorX+dx).clamp(0.0,1.0).toDouble();cursorY=(cursorY+dy).clamp(0.0,1.0).toDouble();});return KeyEventResult.handled;
  }
  void _imageFailed(String path) {
    WidgetsBinding.instance.addPostFrameCallback((_){
      if(!mounted||imageError!=null||game==null||(game!.level.a!=path&&game!.level.b!=path))return;
      setState((){imageError='场景图片暂时不可用。离线时需要先联网打开这一幕，完成缓存后再观察。';game!.pause();});
    });
  }
  Future<void> _reloadImages() async {
    if(game==null)return;
    await Future.wait([AssetImage(game!.level.a).evict(),AssetImage(game!.level.b).evict()]);
    if(mounted)setState((){imageRevision++;_reset(index);});
  }
  Widget _picture(String path,String label,double width,double height,double labelHeight)=>SizedBox(width:width,height:height+labelHeight,child:Column(children:[
    SizedBox(height:labelHeight,child:Text(label,style:const TextStyle(color:FrequencyPalette.muted))),
    Expanded(child:LayoutBuilder(builder:(context,c)=>ClipRRect(borderRadius:BorderRadius.circular(8),child:InteractiveViewer(
      transformationController:transform,minScale:1,maxScale:3,panEnabled:zoom>1,
      onInteractionUpdate:(_){final z=transform.value.getMaxScaleOnAxis();if((z-zoom).abs()>.05)setState(()=>zoom=z);},
      child:Semantics(
      label:'$label，方向键移动光标，Enter确认',image:true,child:GestureDetector(
      excludeFromSemantics:true,
      onTapUp:(d){keyboardCursor=false;final p=normalizeImagePoint(d.localPosition.dx,d.localPosition.dy,c.maxWidth,c.maxHeight);if(p!=null)_tap(p.x,p.y);},
      child:Stack(fit:StackFit.expand,children:[
        Image.asset(path,key:ValueKey('$path-$imageRevision'),fit:BoxFit.contain,errorBuilder:(context,_,__){_imageFailed(path);return const Center(child:Text('场景图片加载失败'));}),
        IgnorePointer(child:CustomPaint(painter:_DifferencePainter(game!,keyboardCursor?Offset(cursorX,cursorY):null))),
      ])))))))]));
  @override void dispose(){platform.unwatchSuspension();WidgetsBinding.instance.removeObserver(this);ticker.dispose();focus.dispose();transform.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>arcadeMotion(context,reduced,Focus(focusNode:focus,autofocus:true,onKeyEvent:_key,child:Scaffold(body:SafeArea(child:LayoutBuilder(builder:(context,c){
    final g=game;
    final mobile=c.maxWidth<700;
    final regionHeight=min(610.0,max(260.0,c.maxHeight-300));
    return SingleChildScrollView(child:Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:1120),child:Padding(padding:const EdgeInsets.symmetric(horizontal:16),child:LayoutBuilder(builder:(context,inner){
      final width=inner.maxWidth;
      final labelHeight=max(28.0,MediaQuery.textScalerOf(context).scale(14)*1.5);
      final imageWidth=mobile?min(width,(regionHeight-labelHeight*2-12)/2*4/3):min((width-12)/2,(regionHeight-labelHeight)*4/3);
      final imageHeight=imageWidth*3/4;
      return Column(
      crossAxisAlignment:CrossAxisAlignment.start,children:[
      ArcadeHeader(title:'双频找不同',subtitle:'观察细节，找出两幅场景的差异',sound:sound,reduced:reduced,playing:g?.status==DifferenceStatus.playing,
        toggleSound:(){setState(()=>sound=!sound);platform.writeValue('manager.arcade.diff.sound.v1',sound?'on':'off');},
        toggleMotion:(){setState(()=>reduced=!reduced);platform.writeValue('manager.arcade.diff.motion.v1',reduced?'reduce':'full');},pause:_pause),
      if(error!=null)GamePanel(title:'场景加载失败',text:error!,action:'重试加载',onAction:_load)
      else if(g==null)const Padding(padding:EdgeInsets.all(48),child:Center(child:CircularProgressIndicator()))
      else...[
        SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:[Readout('场景','${index+1} / ${levels.length}'),const SizedBox(width:8),Readout('已找到','${g.found.length} / ${g.level.spots.length}',color:FrequencyPalette.accent),
          const SizedBox(width:8),Readout('分数','${g.score}'),const SizedBox(width:8),Readout('时间','${g.elapsed.floor()} 秒'),const SizedBox(width:8),Readout('本关纪录','$best')])),
        const SizedBox(height:12),Wrap(spacing:8,runSpacing:8,crossAxisAlignment:WrapCrossAlignment.center,children:[
          OutlinedButton.icon(onPressed:g.status==DifferenceStatus.playing&&g.hintsRemaining>0?_hint:null,icon:const Icon(Icons.lightbulb_outline),label:Text('提示 ${g.hintsRemaining} / 2 · −200分')),
          IconButton(tooltip:'放大',onPressed:zoom<3?()=>_zoom(zoom+.5):null,icon:const Icon(Icons.zoom_in)),
          IconButton(tooltip:'缩小',onPressed:zoom>1?()=>_zoom(zoom-.5):null,icon:const Icon(Icons.zoom_out)),
          TextButton(onPressed:()=>_zoom(1),child:const Text('复位')),
        ]),const SizedBox(height:8),
        Text(g.message.isEmpty?'${g.level.title} · 不限时，错点 −50分':g.message,style:TextStyle(color:g.message.contains('没有')?FrequencyPalette.error:FrequencyPalette.muted)),
        const SizedBox(height:12),
        Center(child:SizedBox(width:width,height:mobile?(imageHeight+labelHeight)*2+12:imageHeight+labelHeight,child:Stack(fit:StackFit.expand,children:[
          ClipRRect(borderRadius:BorderRadius.circular(12),child:mobile?Column(mainAxisAlignment:MainAxisAlignment.center,children:[_picture(g.level.a,'A · 原场景',imageWidth,imageHeight,labelHeight),const SizedBox(height:12),_picture(g.level.b,'B · 变化场景',imageWidth,imageHeight,labelHeight)]):
              Row(mainAxisAlignment:MainAxisAlignment.center,children:[_picture(g.level.a,'A · 原场景',imageWidth,imageHeight,labelHeight),const SizedBox(width:12),_picture(g.level.b,'B · 变化场景',imageWidth,imageHeight,labelHeight)])),
          if(imageError==null&&g.status==DifferenceStatus.ready)GamePanel(title:'第 ${index+1} 幕 · ${g.level.title}',text:'找到全部 ${g.level.spots.length} 处物件差异，忽略细纹理。\n两边都能点，放大后可拖动。\n方向键移动光标，Enter确认，H提示。',action:'开始观察',onAction:_start),
          if(imageError==null&&g.status==DifferenceStatus.paused)GamePanel(title:'观察已暂停',text:'计时暂停，准备好再继续。',action:'继续观察',onAction:_resume,
            extra:TextButton(onPressed:()=>_retry(),child:const Text('重新开始本关'))),
          if(imageError==null&&g.status==DifferenceStatus.cleared)GamePanel(title:index==levels.length-1?'这一章全部完成了':'全部差异已找到',text:'${g.score} 分 · ${g.elapsed.floor()} 秒\n错点 ${g.mistakes} 次 · 提示 ${g.hintsUsed} 次\n${saved?'纪录已保存':'本次纪录未能保存'}',action:index<levels.length-1?'下一幕':'再观察一遍',onAction:()=>_retry(index<levels.length-1?index+1:index)),
          if(imageError!=null)GamePanel(title:'这幕还没有接通信号',text:imageError!,action:'重试加载图片',onAction:_reloadImages),
        ]))),const SizedBox(height:16),
        const Text('已发现的差异不会重复计分。P / Esc 暂停，完成后 R 重玩。',style:TextStyle(color:FrequencyPalette.muted)),
        const SizedBox(height:12),Wrap(spacing:8,runSpacing:8,children:List.generate(levels.length,(i)=>OutlinedButton(
          onPressed:g.status==DifferenceStatus.playing||i>unlocked?null:()=>_retry(i),child:Text(i>unlocked?'第 ${i+1} 幕 · 未解锁':'第 ${i+1} 幕')))),
      ],const SizedBox(height:24),
    ]);
    })))));
  })))));
}
class _DifferencePainter extends CustomPainter {
  final DifferenceEngine game;final Offset? cursor;
  _DifferencePainter(this.game,this.cursor);
  @override void paint(Canvas canvas,Size size){
    final fit=min(size.width/1024,size.height/768),w=1024*fit,h=768*fit;
    final dx=(size.width-w)/2,dy=(size.height-h)/2;
    Rect r(DifferenceSpot s)=>Rect.fromLTWH(dx+s.left*w,dy+s.top*h,s.width*w,s.height*h);
    for(int i=0;i<game.level.spots.length;i++){
      final s=game.level.spots[i];if(!game.found.contains(s.id))continue;
      final box=r(s);canvas.drawOval(box.inflate(3),Paint()..color=FrequencyPalette.accent..style=PaintingStyle.stroke..strokeWidth=3);
      final tp=TextPainter(text:TextSpan(text:'${i+1}',style:const TextStyle(color:FrequencyPalette.background,fontSize:12,fontWeight:FontWeight.bold)),textDirection:TextDirection.ltr)..layout();
      canvas.drawCircle(box.topLeft,10,Paint()..color=FrequencyPalette.accent);tp.paint(canvas,box.topLeft-Offset(tp.width/2,tp.height/2));
    }
    if(game.hint!=null){final center=r(game.hint!).center;canvas.drawCircle(center,min(w,h)*.15,Paint()..color=FrequencyPalette.amber..style=PaintingStyle.stroke..strokeWidth=3);}
    if(cursor!=null){final p=Offset(dx+cursor!.dx*w,dy+cursor!.dy*h);canvas.drawCircle(p,9,Paint()..color=FrequencyPalette.text..style=PaintingStyle.stroke..strokeWidth=2);
      canvas.drawLine(p-const Offset(14,0),p+const Offset(14,0),Paint()..color=FrequencyPalette.text);canvas.drawLine(p-const Offset(0,14),p+const Offset(0,14),Paint()..color=FrequencyPalette.text);}
  }
  @override bool shouldRepaint(covariant _DifferencePainter old)=>true;
}
