import 'package:flutter_test/flutter_test.dart';
import 'package:find_differences_game/game_engine.dart';

void main(){
  final level=DifferenceLevel('测试','a','b',[
    const DifferenceSpot('a','钟',.1,.2,.1,.1),const DifferenceSpot('b','灯',.7,.6,.1,.1)]);
  test('contain rejects margins and inverts every viewport zoom and pan',(){
    for(final width in [320.0,390.0,768.0,1280.0]){
      final height=width;
      expect(normalizeImagePoint(width/2,0,width,height),isNull);
      final p=normalizeImagePoint(width*.15,height/8+width*.25*.75,width,height);
      expect(p!.x,closeTo(.15,1e-8));expect(p.y,closeTo(.25,1e-8));
      final z=normalizeImagePoint(width*.15*2+23,(height/8+width*.25*.75)*2-17,width,height,zoom:2,panX:23,panY:-17);
      expect(z!.x,closeTo(p.x,1e-8));expect(z.y,closeTo(p.y,1e-8));
    }
  });
  test('each unique spot scores once, wrong point never completes, retry is clean',(){
    final g=DifferenceEngine(level)..start();
    expect(g.tap(.15,.25),TapResult.found);final score=g.score;
    expect(g.tap(.15,.25),TapResult.repeated);expect(g.score,score);expect(g.mistakes,0);
    expect(g.tap(.5,.5),TapResult.missed);expect(g.status,DifferenceStatus.playing);
    expect(g.tap(.5,.5),TapResult.ignored);expect(g.mistakes,1);
    g.advance(.7); // A long frame safely pauses, instead of consuming background time.
    expect(g.status,DifferenceStatus.paused);g.resume();g.advance(.3);g.advance(.3);
    expect(g.tap(.75,.65),TapResult.found);expect(g.status,DifferenceStatus.cleared);
    final finalScore=g.score;expect(g.tap(.75,.65),TapResult.ignored);expect(g.score,finalScore);
    final retry=DifferenceEngine(level);expect(retry.found,isEmpty);expect(retry.mistakes,0);
  });
  test('hint does not discover automatically, pause freezes clock and clicks',(){
    final g=DifferenceEngine(level)..start();expect(g.useHint(),isTrue);
    expect(g.found,isEmpty);expect(g.hintsRemaining,1);g.advance(.3);g.pause();
    g.advance(.3);expect(g.elapsed,.3);expect(g.tap(.15,.25),TapResult.ignored);
    g.resume();g.useHint();expect(g.hintsRemaining,0);expect(g.useHint(),isFalse);
    expect(g.tap(-.1,.5),TapResult.ignored);expect(g.mistakes,0);
  });
}
