<%@ WebHandler Language="C#" Class="Service" %>

using System;
using System.Web;
using System.Collections.Generic;
using System.Threading.Tasks;
using System.Xml;
using System.Xml.Serialization;
using Elsinore.ScreenConnect;

public class Service : WebServiceBase
{
	// This sample just sends a message to a session when a host connects. (This can be used as an ad hoc way to make the chat window appear.)
	public void SendMessage(String key, Guid sessionID)
	{
		// This method can potentially be called by anyone (though without a valid session id they'd just get an error), so the trigger passes a simple hardcoded key that's checked here.
		// It should of course be changed for your extension (I just used a password generator to make this one).
		if (key != "hipoDHsIoTPTSbPPnSCR")
			return;

		SessionManagerPool.Demux.AddSessionEvent(sessionID, new SessionEvent
		{
			Host = ExtensionContext.Current.GetSettingValue("Host"),
			EventType = SessionEventType.QueuedMessage,
			Data = ExtensionContext.Current.GetSettingValue("Message"),
		});
	}

	public object GetAchievementDefinitions()
	{
		return AchievementsProvider.GetDefinitions();
	}

	public object GetUsers()
	{
		return AchievementsProvider.GetUsers();
	}

	// TODO: do something with this for long polling
	//public async Task<object> GetAchievementData(long version)
	//{
	//		var newVersion = await WaitForChangeManager.WaitForChangeAsync(version, null);
	//}

	public object GetAchievementDataForLoggedOnUser()
	{
		var username = HttpContext.Current.User.Identity.Name;

		return new
		{
			Username = username,
			Achievements = new List<dynamic> {
					new{
						Title = "Joined Sessions",
						Progress = 3,
						Goal = 5
					},
				}
		};
	}


	public static class AchievementsProvider
	{
		public static List<Definition> GetDefinitions()
		{

			return TryGetObjectXml<List<Definition>>("Definitions");
		}

		public static List<User> GetUsers()
		{
			return TryGetObjectXml<List<User>>("Users");
		}

		private static T TryGetObjectXml<T>(string objectName, Func<XmlReader, bool> func)
		{
			using (var xmlReader = XmlReader.Create(ExtensionContext.Current.BasePath + @"\Achievements.xml"))
			{
				while (xmlReader.Read())
				{
					if (xmlReader.NodeType == XmlNodeType.Element && xmlReader.Name == objectName && func(xmlReader))
						return Deserialize<T>(xmlReader, new XmlRootAttribute(objectName));
				}
			}
			return default(T);
		}

		private static T Deserialize<T>(XmlReader xmlReader, XmlRootAttribute rootAttribute)
		{
			var serilalizer = new XmlSerializer(typeof(T), rootAttribute);
			return (T)serilalizer.Deserialize(xmlReader);
		}

		[XmlType("Definition")]
		public class Definition
		{
			[XmlAttribute("title")]
			public string Title;
			[XmlAttribute("description")]
			public string Description;
			[XmlAttribute("goal")]
			public string Goal;
		}

		[XmlType("UserAchievement")]
		public class UserAchievement
		{
			[XmlAttribute("title'")]
			public string Title;
			[XmlAttribute("progress")]
			public string Progress;
		}

		[XmlRoot("User")]
		public class User
		{
			[XmlAttribute("name")]
			public string Name;
			[XmlElement("UserAchievement")]
			List<UserAchievement> UserAchievements;
		}
	}

}