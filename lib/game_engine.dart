import 'dart:math';

enum DifferenceStatus { ready, playing, paused, cleared }
enum TapResult { found, repeated, missed, ignored }
class DifferenceSpot {
  final String id,label;
  final double left,top,width,height;
  const DifferenceSpot(this.id,this.label,this.left,this.top,this.width,this.height);
  bool contains(double x,double y) => x>=left&&x<=left+width&&y>=top&&y<=top+height;
  factory DifferenceSpot.fromJson(Map<String,dynamic> m){
    final r=m['rect'] as Map<String,dynamic>;
    final s=DifferenceSpot(m['id'] as String,m['label'] as String,
      (r['left'] as num).toDouble(),(r['top'] as num).toDouble(),
      (r['width'] as num).toDouble(),(r['height'] as num).toDouble());
    if(s.left<0||s.top<0||s.width<=0||s.height<=0||s.left+s.width>1||s.top+s.height>1)throw const FormatException('差异位置超出图片');
    return s;
  }
}
class DifferenceLevel {
  final String title,a,b;
  final List<DifferenceSpot> spots;
  DifferenceLevel(this.title,this.a,this.b,this.spots);
  factory DifferenceLevel.fromJson(Map<String,dynamic> m){
    final spots=(m['hotspots'] as List).map((x)=>DifferenceSpot.fromJson(Map<String,dynamic>.from(x as Map))).toList();
    if(spots.isEmpty||spots.map((s)=>s.id).toSet().length!=spots.length)throw const FormatException('关卡差异数据无效');
    return DifferenceLevel(m['title'] as String,m['a'] as String,m['b'] as String,spots);
  }
}
class ImagePoint {
  final double x,y;
  const ImagePoint(this.x,this.y);
}
// Invert zoom/pan, then the actual contain rectangle; letterbox is not a guess.
ImagePoint? normalizeImagePoint(double x,double y,double viewWidth,double viewHeight,
  {double sourceWidth=1024,double sourceHeight=768,double zoom=1,double panX=0,double panY=0}) {
  if(viewWidth<=0||viewHeight<=0||sourceWidth<=0||sourceHeight<=0||zoom<=0)return null;
  x=(x-panX)/zoom;y=(y-panY)/zoom;
  final fit=min(viewWidth/sourceWidth,viewHeight/sourceHeight);
  final w=sourceWidth*fit,h=sourceHeight*fit;
  final dx=(viewWidth-w)/2,dy=(viewHeight-h)/2;
  final u=(x-dx)/w,v=(y-dy)/h;
  if(u<0||v<0||u>1||v>1)return null;
  return ImagePoint(u,v);
}
class DifferenceEngine {
  final DifferenceLevel level;
  DifferenceStatus status=DifferenceStatus.ready;
  final Set<String> found={};
  int mistakes=0,hintsUsed=0;
  double elapsed=0;
  double lastMiss=-10,lastMissX=-10,lastMissY=-10;
  String message='';
  DifferenceSpot? hint;
  DifferenceEngine(this.level);
  int get score=>max(0,found.length*1000-mistakes*50-hintsUsed*200+
    (status==DifferenceStatus.cleared?max(0,(600-elapsed*2).floor()):0));
  int get hintsRemaining=>2-hintsUsed;
  void start(){if(status==DifferenceStatus.ready)status=DifferenceStatus.playing;}
  void pause(){if(status==DifferenceStatus.playing)status=DifferenceStatus.paused;}
  void resume(){if(status==DifferenceStatus.paused)status=DifferenceStatus.playing;}
  void advance(double dt){if(status==DifferenceStatus.playing&&dt>0){if(dt>.5){pause();return;}elapsed+=dt;}}
  TapResult tap(double x,double y){
    if(status!=DifferenceStatus.playing||x<0||y<0||x>1||y>1)return TapResult.ignored;
    for(final spot in level.spots){if(spot.contains(x,y)){
      if(found.contains(spot.id)){message='这一处已经找到了';return TapResult.repeated;}
      found.add(spot.id);message='找到第 ${found.length} 处差异';
      if(hint?.id==spot.id)hint=null;
      if(found.length==level.spots.length){status=DifferenceStatus.cleared;message='所有差异都找到了';}
      return TapResult.found;
    }}
    if(elapsed-lastMiss<.6&&sqrt(pow(x-lastMissX,2)+pow(y-lastMissY,2))<.04)return TapResult.ignored;
    lastMiss=elapsed;lastMissX=x;lastMissY=y;mistakes++;message='这里没有差异，换个细节观察';return TapResult.missed;
  }
  bool useHint(){
    if(status!=DifferenceStatus.playing||hintsRemaining<=0)return false;
    final available=level.spots.where((s)=>!found.contains(s.id)).toList();
    if(available.isEmpty)return false;
    hint=available[hintsUsed%available.length];hintsUsed++;message='提示区域已标出，找到后还需要自己点击';return true;
  }
}
