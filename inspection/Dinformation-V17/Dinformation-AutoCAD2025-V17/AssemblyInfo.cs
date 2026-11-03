using System.Reflection;
using System.Runtime.InteropServices;
using Autodesk.AutoCAD.Runtime;
using DCAD.Dinformation.Core;

[assembly: AssemblyTitle("Dinformation")]
[assembly: AssemblyDescription("DCAD Dinformation - dynamic AutoCAD object information")]
[assembly: AssemblyCompany("DCAD")]
[assembly: AssemblyProduct("Dinformation")]
[assembly: ComVisible(false)]
[assembly: Guid("D4D89A61-3D13-4C61-98FA-E77C4B7731AA")]
[assembly: AssemblyVersion("17.0.0.0")]
[assembly: AssemblyFileVersion("17.0.0.0")]
[assembly: AssemblyInformationalVersion("Dinformation-V17")]
[assembly: ExtensionApplication(typeof(DinformationExtension))]
[assembly: CommandClass(typeof(DinformationCommands))]
