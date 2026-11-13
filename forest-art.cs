using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Windows.Forms;

public class ForestWindow : Form {
 public float LayoutScale=1;
 public ForestWindow(){DoubleBuffered=true;}
 protected override void OnPaintBackground(PaintEventArgs e) {
  base.OnPaintBackground(e);
  var g=e.Graphics; var state=g.Save();g.TranslateTransform(AutoScrollPosition.X,AutoScrollPosition.Y);g.ScaleTransform(LayoutScale,LayoutScale);
  using(var b=new SolidBrush(Color.White))g.FillRectangle(b,24,105,284,492);
  using(var b=new SolidBrush(ColorTranslator.FromHtml("#E6EEDC")))g.FillRectangle(b,332,105,724,492);
  using(var b=new SolidBrush(ColorTranslator.FromHtml("#EAEDE1")))g.FillRectangle(b,24,618,1032,148);
  g.Restore(state);
 }
}
public class ForestScene : Control {
 public string TimeText="25:00", PhaseText="MAKE ROOM FOR FOCUS";
 public double Progress=0, NoteProgress=0;
 public bool Resting=false, Paused=false;
 public ForestScene(){DoubleBuffered=true;BackColor=C("#E6EEDC");}
 static Color C(string s){return ColorTranslator.FromHtml(s);}
 void Rect(Graphics g,string c,float x,float y,float w,float h){using(var b=new SolidBrush(C(c)))g.FillRectangle(b,x,y,w,h);}
 void Ell(Graphics g,string c,float x,float y,float w,float h){using(var b=new SolidBrush(C(c)))g.FillEllipse(b,x,y,w,h);}
 void Line(Graphics g,string c,float w,float x,float y,float xx,float yy){using(var p=new Pen(C(c),w)){p.StartCap=LineCap.Round;p.EndCap=LineCap.Round;g.DrawLine(p,x,y,xx,yy);}}
 void Caption(Graphics g,string text,float size,string color,float x,float y,float w,bool bold=false){
  using(var f=new Font("Segoe UI",size*96/72,bold?FontStyle.Bold:FontStyle.Regular,GraphicsUnit.Pixel))
  using(var b=new SolidBrush(C(color)))using(var sf=new StringFormat{Alignment=StringAlignment.Center})g.DrawString(text,f,b,new RectangleF(x,y,w,65),sf);
 }
 void Poly(Graphics g,string c,PointF[] points){using(var b=new SolidBrush(C(c)))g.FillPolygon(b,points);}
 protected override void OnPaint(PaintEventArgs e){
  base.OnPaint(e);var g=e.Graphics;g.SmoothingMode=SmoothingMode.AntiAlias;g.TextRenderingHint=System.Drawing.Text.TextRenderingHint.ClearTypeGridFit;
  g.ScaleTransform(Width/724f,Height/397f);
  double progress=Math.Max(0,Math.Min(1,Progress));
  // The room is built from native vector shapes, at the current display DPI.
  Rect(g,"#D9E3CD",153,40,418,200);
  Rect(g,Resting?"#E5EACD":"#EDF1DF",220,49,284,144);
  // Daylight moves with the interval; pauses freeze both the clock and the scene.
  Ell(g,"#E1C78E",(float)(246+progress*192),66,30,30);
  Poly(g,"#C9D7BA",new[]{new PointF(220,165),new PointF(283,120),new PointF(365,165),new PointF(432,132),new PointF(504,173),new PointF(504,193),new PointF(220,193)});
  Poly(g,"#B6CAA5",new[]{new PointF(220,184),new PointF(304,159),new PointF(404,181),new PointF(504,155),new PointF(504,193),new PointF(220,193)});
  Rect(g,"#718869",213,42,298,7);Rect(g,"#718869",213,42,7,158);Rect(g,"#718869",504,42,7,158);
  Rect(g,"#718869",358,47,7,146);Rect(g,"#718869",213,193,298,8);Rect(g,"#A5B598",205,201,314,8);
  // A light pool, a desk lamp, a notebook and a cup are StudyGuard's own motif.
  Poly(g,Paused?"#DFE6D2":"#ECEACB",new[]{new PointF(191,143),new PointF(296,143),new PointF(346,246),new PointF(160,246)});
  Line(g,"#526D54",7,176,227,176,163);Line(g,"#526D54",7,176,163,213,117);
  Poly(g,"#527356",new[]{new PointF(199,112),new PointF(231,112),new PointF(249,144),new PointF(184,144)});
  Ell(g,"#4A674E",152,222,49,10);
  Ell(g,"#C2CFB2",171,263,393,19);
  Rect(g,"#9CAB88",135,251,454,10);Rect(g,"#ABB899",149,261,426,5);
  Rect(g,"#869A77",161,266,8,27);Rect(g,"#869A77",556,266,8,27);
  if(Resting){
   Rect(g,"#527258",278,225,160,23);Rect(g,"#F5F0D7",284,230,149,12);Rect(g,"#78926A",278,223,162,6);
   Rect(g,"#BA866C",399,222,7,15);
  }else{
   Poly(g,"#FAF8EB",new[]{new PointF(271,202),new PointF(360,210),new PointF(360,247),new PointF(256,237)});
   Poly(g,"#FFFDF3",new[]{new PointF(360,210),new PointF(453,202),new PointF(468,237),new PointF(360,247)});
   Line(g,"#D5D9BE",1,360,212,360,245);
   // Ink grows only with estimated focused time credited by the existing accounting.
   double strokes=Math.Max(0,Math.Min(1,NoteProgress))*12;
   for(int i=0;i<12;i++){
    float partial=(float)Math.Max(0,Math.Min(1,strokes-i));if(partial<=0)continue;
    bool right=i>=6;int row=i%6;float x=right?375:277,y=right?215+row*4:210+row*4;
    float length=45+(i%3)*8;
    Line(g,i%4==0?"#5E8060":"#9DAF89",1.5f,x,y,x+length*partial,y+(right?-3:3)*partial);
   }
   // A pencil rests beside the page. It never uses rapid animation.
   Line(g,"#BC9161",4,470,214,491,239);Line(g,"#4D6350",2,491,239,494,243);
  }
  Ell(g,"#9EAC8C",493,243,43,7);
  Rect(g,"#FAF8E9",498,220,28,25);Ell(g,"#FAF8E9",498,215,28,10);Ell(g,"#AC8B66",502,218,20,5);
  using(var p=new Pen(C("#FAF8E9"),4))g.DrawArc(p,520,222,16,15,-90,270);
  if(Resting){
   using(var p=new Pen(C("#9BAB8B"),1.5f))g.DrawBezier(p,510,207,501,200,519,198,511,188);
  }
  string caption=Paused?"YOUR PLACE IS SAVED":Resting?"STEP AWAY. THE DESK CAN WAIT.":"SMALL STEPS LEAVE A MARK.";
  Caption(g,caption,8,"#647B58",0,286,724);
  Line(g,"#C9D6BA",2,302,311,422,311);
  if(progress>0)Line(g,"#6A8756",2,302,311,(float)(302+120*progress),311);
  Ell(g,"#6A8756",(float)(299+120*progress),308,6,6);
  Caption(g,PhaseText,9,"#5B7352",0,322,724,true);
  Caption(g,TimeText,32,"#254B38",0,342,724);
 }
}


