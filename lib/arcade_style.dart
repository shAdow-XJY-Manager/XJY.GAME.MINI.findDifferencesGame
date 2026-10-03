import 'package:flutter/material.dart';

abstract final class FrequencyPalette {
  static const background = Color(0xFF111315);
  static const surface = Color(0xFF1B1E20);
  static const elevated = Color(0xFF25292C);
  static const text = Color(0xFFF4F2E9);
  static const muted = Color(0xFFADB1A9);
  static const accent = Color(0xFFD6EF36);
  static const amber = Color(0xFFFFB23F);
  static const border = Color(0xFF41484B);
  static const error = Color(0xFFFF9691);
}

ThemeData arcadeTheme() => ThemeData(
  useMaterial3: true,
  colorScheme: const ColorScheme.dark(primary: FrequencyPalette.accent,
    onPrimary: FrequencyPalette.background, secondary: FrequencyPalette.amber,
    surface: FrequencyPalette.surface, onSurface: FrequencyPalette.text,
    error: FrequencyPalette.error, outline: FrequencyPalette.border),
  scaffoldBackgroundColor: FrequencyPalette.background,
  textTheme: const TextTheme(
    bodyLarge: TextStyle(fontSize:16,height:1.5),
    bodyMedium: TextStyle(fontSize:14,height:1.5),
    titleLarge: TextStyle(fontSize:24,fontWeight:FontWeight.w700)),
  filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(
    minimumSize: const Size(48,48),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)))),
  outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(
    minimumSize: const Size(48,48),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)))),
);

Widget arcadeMotion(BuildContext context, bool reduced, Widget child) {
  final effective = reduced || MediaQuery.disableAnimationsOf(context);
  return MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: effective),
    child: Theme(
      data: Theme.of(context).copyWith(
        splashFactory: effective ? NoSplash.splashFactory : Theme.of(context).splashFactory,
      ),
      child: child,
    ),
  );
}

class ArcadeHeader extends StatelessWidget {
  final String title, subtitle;
  final bool sound, reduced, playing;
  final VoidCallback toggleSound, toggleMotion, pause;
  const ArcadeHeader({super.key,required this.title,required this.subtitle,
    required this.sound,required this.reduced,required this.playing,
    required this.toggleSound,required this.toggleMotion,required this.pause});
  @override Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical:12),
    child: Wrap(alignment:WrapAlignment.spaceBetween,crossAxisAlignment:WrapCrossAlignment.center,
      spacing:24,runSpacing:12,children:[
      Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('频率站 / 街机',style:TextStyle(color:FrequencyPalette.accent,fontSize:14)),
        Text(title,style:Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight:FontWeight.w800)),
        Text(subtitle,style:const TextStyle(color:FrequencyPalette.muted,fontSize:14)),
      ]),
      Wrap(spacing:8,children:[
        IconButton(tooltip:sound?'关闭声音':'开启声音',onPressed:toggleSound,
          icon:Icon(sound?Icons.volume_up_rounded:Icons.volume_off_rounded)),
        IconButton(tooltip:reduced?'开启动态效果':'减少动态效果',onPressed:toggleMotion,
          icon:Icon(reduced?Icons.motion_photos_off:Icons.motion_photos_on)),
        OutlinedButton.icon(onPressed:playing?pause:null,
          icon:const Icon(Icons.pause_rounded),label:const Text('暂停')),
      ])]));
}

class Readout extends StatelessWidget {
  final String label, value;
  final Color? color;
  const Readout(this.label,this.value,{super.key,this.color});
  @override Widget build(BuildContext context)=>Container(
    padding:const EdgeInsets.symmetric(horizontal:16,vertical:10),
    decoration:BoxDecoration(color:FrequencyPalette.surface,borderRadius:BorderRadius.circular(8),
      border:Border.all(color:FrequencyPalette.border)),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(label,style:const TextStyle(color:FrequencyPalette.muted,fontSize:14)),
      Text(value,style:TextStyle(color:color??FrequencyPalette.text,fontSize:22,fontWeight:FontWeight.w700)),
    ]));
}

class GamePanel extends StatelessWidget {
  final String title, text, action;
  final VoidCallback onAction;
  final Widget? extra;
  const GamePanel({super.key,required this.title,required this.text,
    required this.action,required this.onAction,this.extra});
  @override Widget build(BuildContext context) => LayoutBuilder(builder:(context,c) {
    final compact=c.maxWidth<400;
    return Center(child:SingleChildScrollView(child:Container(
      constraints:const BoxConstraints(maxWidth:440),margin:EdgeInsets.all(compact?8:20),
      padding:EdgeInsets.all(compact?12:24),
      decoration:BoxDecoration(color:FrequencyPalette.surface,borderRadius:BorderRadius.circular(12),
        border:Border.all(color:FrequencyPalette.border)),
      child:Column(mainAxisSize:MainAxisSize.min,children:[
        Text(title,textAlign:TextAlign.center,style:Theme.of(context).textTheme.headlineSmall?.copyWith(
          fontWeight:FontWeight.w800,fontSize:compact?20:24)),
        SizedBox(height:compact?8:12),Text(text,textAlign:TextAlign.center,
          style:TextStyle(fontSize:14,height:compact?1.4:1.5)),SizedBox(height:compact?12:20),
        FilledButton(onPressed:onAction,child:Text(action)),if(extra!=null)...[const SizedBox(height:8),extra!],
      ]))));
  });
}
