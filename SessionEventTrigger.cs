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
	public Proc GetDeferredActionIfApplicable(SessionEventTriggerEvent sessionEventTriggerEvent)
	{
		if (sessionEventTriggerEvent.SessionEvent.EventType == SessionEventType.CreatedSession)
			System.Diagnostics.Debug.WriteLine("Test");

		return null;
	}

	private void SendRequestToService(string endpoint, params string[] args)
	{
		using (var webClient = new ScreenConnect.WebClient())
		{
			
		}
	}
}