using System;
using System.Collections;
using System.Collections.Generic;
using System.Configuration;
using System.IO;
using System.Linq;
using System.Net;
using System.Threading;
using System.Text;
using System.Text.RegularExpressions;
using System.Web;
using ScreenConnect;

public class SessionEventTriggerAccessor : IDynamicSessionEventTrigger
{
	const string key = "wXJSJ95g4Q2CZChNCW98";

	public Proc GetDeferredActionIfApplicable(SessionEventTriggerEvent sessionEventTriggerEvent)
	{
		if (sessionEventTriggerEvent.SessionEvent.EventType == SessionEventType.CreatedSession)
			SendRequestToService("UpdateAchievementForUser", key, "Baby Steps", "1", sessionEventTriggerEvent.SessionEvent.Host);

		return null;
	}

	void SendRequestToService(params string[] args)
	{
		using (var webClient = new ScreenConnect.WebClient())
		{
			var request = webClient.DownloadString(GetExtensionServiceUri(args));
		}
	}

	Uri GetExtensionServiceUri(params string[] args)
	{
		var builder = new UriBuilder(new Uri(
			ServerExtensions.GetWebServerUri(null, false, false, null).Uri,
			ExtensionContext.Current
			.BasePath
			.Split('\\')
			.SafeNav(_ => _.Skip2(_.Count() - 2)
			.Take2(2))
			.ToList()
			.SafeDo(_ => _.Add("Service.ashx"))
			.Join('/')
			));
		builder.Path += '/' + args.Join('/');
		return builder.Uri;
	}
}