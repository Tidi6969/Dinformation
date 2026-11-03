using System.Reflection;
using System.Runtime.InteropServices;
using GrxCAD.Runtime;
using DCAD.Dinformation.Core;

[assembly: AssemblyTitle("Dinformation")]
[assembly: AssemblyDescription("DCAD Dinformation - GstarCAD 2018 launcher with temporary AutoLISP engine")]
[assembly: AssemblyCompany("DCAD")]
[assembly: AssemblyProduct("Dinformation")]
[assembly: ComVisible(false)]
[assembly: Guid("B03192A2-CFB8-4AE4-9D75-201800000011")]
[assembly: AssemblyVersion("17.0.0.0")]
[assembly: AssemblyFileVersion("17.0.0.0")]
[assembly: AssemblyInformationalVersion("Dinformation-V17")]
[assembly: ExtensionApplication(typeof(DinformationExtension))]
[assembly: CommandClass(typeof(DinformationCommands))]
