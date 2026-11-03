using System;
using Autodesk.AutoCAD.ApplicationServices;
using Autodesk.AutoCAD.Runtime;
using DCAD.Dinformation.Data;
using DCAD.Dinformation.Information;
using DCAD.Dinformation.UI;
using Application = Autodesk.AutoCAD.ApplicationServices.Application;

namespace DCAD.Dinformation.Core
{
    public sealed class DinformationCommands
    {
        [CommandMethod(UiText.CommandName, CommandFlags.Modal)]
        public void RunDinformation()
        {
            Lang.BeginCommand();
            Lang.Reload();

            Document document = Application.DocumentManager.MdiActiveDocument;
            if (document == null)
            {
                return;
            }

            try
            {
                LispInfoEngine.LoadForCommand();
                using (var session = new InformationSession(document))
                {
                    session.Run();
                }
            }
            catch (System.Exception exception)
            {
                RuntimeLog.Error("Unhandled command exception.", exception);
                document.Editor.WriteMessage(UiText.ErrorPrefix + exception.Message);
            }
        }
    }

    public sealed class DinformationExtension : IExtensionApplication
    {
        public void Initialize()
        {
            LispInfoEngine.CleanupStaleFiles();
            string languageError;
            if (!LanguageResourceAudit.TryRun(out languageError))
            {
                RuntimeLog.Error("LanguageResourceAudit failed: " + languageError, null);
            }
            RuntimeLog.Info("Dinformation V17 loaded. AutoCADTargetVersion=2025");
        }

        public void Terminate()
        {
            RuntimeLog.Info("Dinformation V17 unloaded.");
        }
    }
}
