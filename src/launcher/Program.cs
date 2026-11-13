using System;
using System.IO;
using System.Threading;
using System.Management.Automation;
using System.Management.Automation.Runspaces;
using System.Windows.Forms;
using System.Reflection;
[assembly: AssemblyTitle("FocusRelay")]
[assembly: AssemblyDescription("Quiet Desk focus companion for Windows")]
[assembly: AssemblyVersion("1.3.0.0")]
internal static class Program {
 [STAThread] static int Main(string[] args) {
  string root=AppDomain.CurrentDomain.BaseDirectory;
  string app=Path.Combine(root,"app"), data=Path.Combine(root,"data");
  bool check=Array.IndexOf(args,"--smoke-test")>=0 || Array.IndexOf(args,"--preview")>=0;
  try {
   // Do not migrate settings while a previous branded version is still running.
   if(!check){
    try{using(var previous=Mutex.OpenExisting("Local\\StudyGuardActivityWatch")){
     bool acquired=false;
     try{acquired=previous.WaitOne(0);}catch(AbandonedMutexException){acquired=true;}
     if(!acquired)return 0;
     previous.ReleaseMutex();
    }}catch(WaitHandleCannotBeOpenedException){}
   }
   var initial=InitialSessionState.CreateDefault();
   // Process-local policy; no machine or user policy is changed.
   initial.ExecutionPolicy=Microsoft.PowerShell.ExecutionPolicy.Bypass;
   using(var runspace=RunspaceFactory.CreateRunspace(initial)) {
    runspace.ApartmentState=ApartmentState.STA;
    runspace.ThreadOptions=PSThreadOptions.UseCurrentThread;
    runspace.Open();
    using(var ps=PowerShell.Create()) {
     ps.Runspace=runspace;
     ps.AddCommand(Path.Combine(app,"Initialize-FocusRelay.ps1")); ps.Invoke();
     if(ps.HadErrors)throw new Exception(ps.Streams.Error[0].ToString());
     ps.Commands.Clear();ps.Streams.Error.Clear();
     ps.AddCommand(Path.Combine(app,"FocusRelay.ps1"));
     if(Array.IndexOf(args,"--smoke-test")>=0)ps.AddParameter("SmokeTest");
     if(Array.IndexOf(args,"--preview")>=0)ps.AddParameter("DeskPreview");
     var output=ps.Invoke();
     if(check) {using(var writer=new StreamWriter(Path.Combine(data,"verification.txt"))){foreach(var line in output)writer.WriteLine(line); foreach(var error in ps.Streams.Error)writer.WriteLine(error);}}
     if(ps.HadErrors)throw new Exception(ps.Streams.Error[0].ToString());
    }
   }
   return 0;
  } catch(Exception ex) {
   try{File.WriteAllText(Path.Combine(data,"startup-error.txt"),ex.ToString());}catch{}
   if(!check)MessageBox.Show("FocusRelay could not start.\n\n"+ex.Message+"\n\nExtract the complete ZIP to a writable folder. See startup-error.txt for details.","FocusRelay",MessageBoxButtons.OK,MessageBoxIcon.Error);
   return 1;
  }
 }
}
