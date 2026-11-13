using System;
using System.IO;
using System.Threading;
using System.Management.Automation;
using System.Management.Automation.Runspaces;
using System.Windows.Forms;
using System.Reflection;
[assembly: AssemblyTitle("StudyGuard")]
[assembly: AssemblyDescription("Quiet Desk focus companion for Windows")]
[assembly: AssemblyVersion("1.2.0.0")]
internal static class Program {
 [STAThread] static int Main(string[] args) {
  string root=AppDomain.CurrentDomain.BaseDirectory;
  bool check=Array.IndexOf(args,"--smoke-test")>=0 || Array.IndexOf(args,"--preview")>=0;
  try {
   var initial=InitialSessionState.CreateDefault();
   // Process-local policy; no machine or user policy is changed.
   initial.ExecutionPolicy=Microsoft.PowerShell.ExecutionPolicy.Bypass;
   using(var runspace=RunspaceFactory.CreateRunspace(initial)) {
    runspace.ApartmentState=ApartmentState.STA;
    runspace.ThreadOptions=PSThreadOptions.UseCurrentThread;
    runspace.Open();
    using(var ps=PowerShell.Create()) {
     ps.Runspace=runspace;
     ps.AddCommand(Path.Combine(root,"Initialize-StudyGuard.ps1")); ps.Invoke();
     if(ps.HadErrors)throw new Exception(ps.Streams.Error[0].ToString());
     ps.Commands.Clear();ps.Streams.Error.Clear();
     ps.AddCommand(Path.Combine(root,"StudyGuard.ps1"));
     if(Array.IndexOf(args,"--smoke-test")>=0)ps.AddParameter("SmokeTest");
     if(Array.IndexOf(args,"--preview")>=0)ps.AddParameter("ForestPreview");
     var output=ps.Invoke();
     if(check) {using(var writer=new StreamWriter(Path.Combine(root,"verification.txt"))){foreach(var line in output)writer.WriteLine(line); foreach(var error in ps.Streams.Error)writer.WriteLine(error);}}
     if(ps.HadErrors)throw new Exception(ps.Streams.Error[0].ToString());
    }
   }
   return 0;
  } catch(Exception ex) {
   try{File.WriteAllText(Path.Combine(root,"startup-error.txt"),ex.ToString());}catch{}
   if(!check)MessageBox.Show("StudyGuard could not start.\n\n"+ex.Message+"\n\nExtract the complete ZIP to a writable folder. See startup-error.txt for details.","StudyGuard",MessageBoxButtons.OK,MessageBoxIcon.Error);
   return 1;
  }
 }
}
