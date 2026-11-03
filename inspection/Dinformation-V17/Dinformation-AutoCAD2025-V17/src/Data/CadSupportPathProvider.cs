using System;
using System.Globalization;
using AcApp = Autodesk.AutoCAD.ApplicationServices.Application;

namespace DCAD.Dinformation.Data
{
    internal static class CadSupportPathProvider
    {
        internal const string HostName = "AutoCAD 2025";
        internal static string ReadSupportPathText()
        {
            try { return Convert.ToString(AcApp.GetSystemVariable("ACADPREFIX"), CultureInfo.InvariantCulture) ?? string.Empty; }
            catch { return string.Empty; }
        }
        internal static string TryReadProfileName()
        {
            try { return Convert.ToString(AcApp.GetSystemVariable("CPROFILE"), CultureInfo.InvariantCulture) ?? string.Empty; }
            catch { return string.Empty; }
        }
    }
}
