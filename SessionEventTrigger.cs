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
		{
			SendRequestToService("UpdateAchievementForUser", key, "Baby Steps", "1", sessionEventTriggerEvent.SessionEvent.Host);
		}
		else if (sessionEventTriggerEvent.SessionEvent.EventType == SessionEventType.QueuedCommand)
		{
			SendRequestToService("UpdateAchievementForUser", key, "Make It So", "1", sessionEventTriggerEvent.SessionEvent.Host);
		}
		else if (sessionEventTriggerEvent.SessionEvent.EventType == SessionEventType.Connected)
		{
			if (sessionEventTriggerEvent.SessionConnection.ProcessType == ProcessType.Host)
			{
				int currentProgress;
				if (int.TryParse(SendRequestToService("GetAchievementProgressForUser", "Hat Trick", sessionEventTriggerEvent.SessionEvent.Host) ?? "0", out currentProgress))
				{
					var newProgress = currentProgress;
					switch (sessionEventTriggerEvent.Session.SessionType)
					{
						case SessionType.Access:
							newProgress |= 1;
							break;
						case SessionType.Meeting:
							newProgress |= 2;
							break;
						case SessionType.Support:
							newProgress |= 4;
							break;
					}
					if (newProgress != currentProgress)
						SendRequestToService("UpdateAchievementForUser", key, "Hat Trick", newProgress.ToString(), sessionEventTriggerEvent.SessionEvent.Host);
				}
			}
		}

		return null;
	}

	string SendRequestToService(params string[] args)
	{
		using (var webClient = new ScreenConnect.WebClient())
		{
			var request = webClient.DownloadString(GetExtensionServiceUri(args));
			return request == "null" ? null : request.Trim(' ', '\t', '\n', '\v', '\f', '\r', '"');
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