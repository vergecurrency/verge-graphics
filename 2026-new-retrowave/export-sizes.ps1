Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Globalization;
public static class RetrowaveExport {
    static double[] Fit(Bitmap source, double intercept, double slope, int first, int last) {
        double sy=0,sx=0,syy=0,syx=0,n=0;
        for(int y=first;y<=last;y++) {
            double expected=intercept+slope*(y+.5);
            for(int x=Math.Max(0,(int)expected-4);x<Math.Min(255,(int)expected+4);x++) {
                double g0=source.GetPixel(x,y).G,g1=source.GetPixel(x+1,y).G;
                if((g0-96.5)*(g1-96.5)<=0 && g0!=g1) {
                    double px=x+.5+(96.5-g0)/(g1-g0),py=y+.5;
                    n++; sy+=py; sx+=px; syy+=py*py; syx+=py*px; break;
                }
            }
        }
        double b=(n*syx-sy*sx)/(n*syy-sy*sy);
        return new double[]{(sx-b*sy)/n,b};
    }
    static bool Cyan(double x,double y,double[] outer,double[] inner,double[] triangle) {
        double o=outer[0]+outer[1]*y,i=inner[0]+inner[1]*y,t=triangle[0]+triangle[1]*y;
        return (x>=t && x<=512-t) || (x>=o && x<=512-o && (x<=i || x>=512-i));
    }
    public static void Run(string sourcePath,string output) {
        CultureInfo.CurrentCulture=CultureInfo.InvariantCulture;
        using(var source=new Bitmap(sourcePath)) {
            var outer=Fit(source,-48,.435,160,490);
            var inner=Fit(source,63,.434,10,420);
            var triangle=Fit(source,174,.423,10,170);
            Console.WriteLine("Fitted edges: outer={0}+{1}y; inner={2}+{3}y; triangle={4}+{5}y",outer[0],outer[1],inner[0],inner[1],triangle[0],triangle[1]);
            double bottom=outer[0]+outer[1]*512;
            string svg=String.Format("<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"512\" height=\"512\" viewBox=\"0 0 512 512\"><rect width=\"512\" height=\"512\" fill=\"#310439\"/><g fill=\"#34bde2\"><path d=\"M {0},0 H {1} L 256,{2} Z\"/><path d=\"M {3},0 H {4} L 256,{5} {6},0 H {7} L {8},512 H {9} Z\"/></g></svg>\n",triangle[0],512-triangle[0],(256-triangle[0])/triangle[1],outer[0],inner[0],(256-inner[0])/inner[1],512-inner[0],512-outer[0],512-bottom,bottom);
            File.WriteAllText(Path.Combine(output,"verge-retrowave-master.svg"),svg);
            foreach(int size in new int[]{16,32,48,64,128,180,256,512,1024,1536,2048,4096}) {
                string path=Path.Combine(output,"verge-retrowave-"+size+"x"+size+".png");
                if(size==512) { File.Copy(sourcePath,path,true); continue; }
                using(var bitmap=new Bitmap(size,size,PixelFormat.Format24bppRgb)) {
                    double scale=512.0/size;
                    for(int y=0;y<size;y++) for(int x=0;x<size;x++) {
                        bool a=Cyan(x*scale,y*scale,outer,inner,triangle);
                        bool b=Cyan((x+1)*scale,y*scale,outer,inner,triangle);
                        bool c=Cyan(x*scale,(y+1)*scale,outer,inner,triangle);
                        bool d=Cyan((x+1)*scale,(y+1)*scale,outer,inner,triangle);
                        double coverage=a?1:0;
                        if(a!=b || a!=c || a!=d || a!=Cyan((x+.5)*scale,(y+.5)*scale,outer,inner,triangle)) {
                            int count=0;
                            for(int yy=0;yy<16;yy++) for(int xx=0;xx<16;xx++)
                                if(Cyan((x+(xx+.5)/16)*scale,(y+(yy+.5)/16)*scale,outer,inner,triangle)) count++;
                            coverage=count/256.0;
                        }
                        bitmap.SetPixel(x,y,Color.FromArgb((int)Math.Round(49+3*coverage),(int)Math.Round(4+185*coverage),(int)Math.Round(57+169*coverage)));
                    }
                    bitmap.Save(path,ImageFormat.Png);
                }
                Console.WriteLine("Saved "+size+"x"+size);
            }
        }
    }
}
'@
[RetrowaveExport]::Run('C:\Users\justi\Documents\verge\v26\newicon.png', $PSScriptRoot)
