using System;
using GrxCAD.ApplicationServices;
using GrxCAD.Runtime;
using DCAD.Dinformation.Data;
using GstarApp = GrxCAD.ApplicationServices.Application;

namespace DCAD.Dinformation.Core
{
    public sealed class DinformationCommands
    {
        [CommandMethod("Dinformation", CommandFlags.Modal)]
        public void Dinformation()
        {
            Document doc = GstarApp.DocumentManager.MdiActiveDocument;
            if (doc == null)
            {
                return;
            }

            Lang.BeginCommand();
            Lang.Reload();

            string auditError;
            if (!LanguageResourceAudit.TryRun(out auditError))
            {
                doc.Editor.WriteMessage("\nDinformation " + Lang.T("ErrorPrefix") + auditError);
                RuntimeLog.Error("Language resource audit failed.", new InvalidOperationException(auditError));
                return;
            }

            try
            {
                LispLauncher.Start(doc);
            }
            catch (System.Exception ex)
            {
                string message = Lang.F("LauncherSendError", ex.Message);
                doc.Editor.WriteMessage("\nDinformation " + Lang.T("ErrorPrefix") + message);
                RuntimeLog.Error("GstarCAD 2018 LISP launcher failed.", ex);
            }
        }
    }

    public sealed class DinformationExtension : IExtensionApplication
    {
        public void Initialize()
        {
            try
            {
                LispLauncher.CleanupStaleFiles();
                RuntimeLog.Info("Dinformation V17 loaded. GstarCADTargetVersion=2018; Engine=TemporaryLISP.");
            }
            catch (System.Exception ex)
            {
                RuntimeLog.Error("Initialize cleanup failed.", ex);
            }
        }

        public void Terminate()
        {
            RuntimeLog.Info("Dinformation V17 unloaded.");
        }
    }
}
