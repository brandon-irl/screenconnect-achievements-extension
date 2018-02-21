<%@ WebHandler Language="C#" Class="Service" %>

using System;
using System.Text;
using System.IO;
using System.Web;
using System.Linq;
using System.Collections.Generic;
using System.Threading.Tasks;
using System.Xml;
using System.Xml.Linq;
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
		return AchievementsProvider.GetUser(username);
	}


	//	*****************************************Helper Stuff*****************************************
	public static class AchievementsProvider        // TODO: polymorphism
	{
		const string xmlFileName = "Achievements.xml";

		public static List<Definition> GetDefinitions()
		{
			return TryReadObjectXml<List<Definition>>("Definitions");
		}

		public static User GetUser(string username)
		{
			var user = TryReadObjectXml<User>("User", (_ => _.GetAttribute("Name") == username));
			if (user == null)
			{
				user = EnsureUserExistsInXml(username);
			}
			return user;
		}

		public static List<User> GetUsers()
		{
			return TryReadObjectXml<List<User>>("Users");
		}

		private static T TryReadObjectXml<T>(string objectName)
		{
			return TryReadObjectXml<T>(objectName, (_ => true));
		}

		private static T TryReadObjectXml<T>(string objectName, Func<XmlReader, bool> additionalValidator)
		{
			try
			{

				using (var xmlReader = XmlReader.Create(ExtensionContext.Current.BasePath + @"\" + xmlFileName))
				{
					while (xmlReader.Read())
					{
						if (xmlReader.NodeType == XmlNodeType.Element && xmlReader.Name == objectName && additionalValidator(xmlReader))
							return Deserialize<T>(xmlReader, new XmlRootAttribute(objectName));
					}
				}
			}
			catch (FileNotFoundException)
			{
				EnsureAchievementsXmlExists();
				return TryReadObjectXml<T>(objectName, additionalValidator);
			}
			return default(T);
		}

		/// <typeparam name="T">Type of object to be written</typeparam>
		/// <typeparam name="K">Type of parent of object to be written</typeparam>
		/// <param name="obj">Object to be written</param>
		private static void WriteObjectXml<T, K>(T obj)
		{
			WriteObjectXml<T, K>(obj, (_ => true));
		}

		/// <typeparam name="T">Type of object to be written</typeparam>
		/// <typeparam name="K">Type of parent of object to be written</typeparam>
		/// <param name="obj">Object to be written</param>
		/// <param name="parentValidator">Custom function for validating parent object</param>
		private static void WriteObjectXml<T, K>(T obj, Func<object, bool> parentValidator)
		{
			try
			{
				var xdoc = XDocument.Load(ExtensionContext.Current.BasePath + @"\" + xmlFileName);
				var parentElement = xdoc.Descendants(typeof(K).Name)
						.Where(_ => parentValidator(_))
						.FirstOrDefault();
				if (parentElement != null)
				{
					parentElement.Add(ToXElement<T>(obj));
					xdoc.Save(ExtensionContext.Current.BasePath + @"\" + xmlFileName);
				}
				else
					throw new ArgumentException("Could not find specified parent in XML");
			}
			catch (FileNotFoundException)
			{
				EnsureAchievementsXmlExists();
			}
		}

		private static T Deserialize<T>(XmlReader xmlReader, XmlRootAttribute rootAttribute)
		{
			var serilalizer = new XmlSerializer(typeof(T), rootAttribute);
			return (T)serilalizer.Deserialize(xmlReader);
		}

		private static XElement ToXElement<T>(object obj)
		{
			using (var memoryStream = new MemoryStream())
			{
				using (TextWriter streamWriter = new StreamWriter(memoryStream))
				{
					var xmlSerializer = new XmlSerializer(typeof(T));
					xmlSerializer.Serialize(streamWriter, obj);
					return XElement.Parse(Encoding.ASCII.GetString(memoryStream.ToArray()));
				}
			}
		}

		private static T FromXElement<T>(XElement xElement)
		{
			var xmlSerializer = new XmlSerializer(typeof(T));
			return (T)xmlSerializer.Deserialize(xElement.CreateReader());
		}

		private static User EnsureUserExistsInXml(string username)
		{
			var user = new User
			{
				Name = username
			};
			WriteObjectXml<User, Users>(user);
			return GetUser(username);
		}

		private static void EnsureAchievementsXmlExists()
		{
			// TODO
		}

		[SerializableAttribute()]
		[XmlTypeAttribute(AnonymousType = true)]
		[XmlRootAttribute(Namespace = "", IsNullable = false)]
		public partial class Achievements
		{
			[XmlElementAttribute("Definitions", typeof(Definitions), Form = System.Xml.Schema.XmlSchemaForm.Unqualified)]
			[XmlElementAttribute("Users", typeof(Users), Form = System.Xml.Schema.XmlSchemaForm.Unqualified)]
			public object[] Items;
		}

		[System.SerializableAttribute()]
		[XmlTypeAttribute(AnonymousType = true)]
		public partial class Definitions
		{
			[XmlElementAttribute("Definition", Form = System.Xml.Schema.XmlSchemaForm.Unqualified)]
			public Definition[] Definition;
		}

		[XmlTypeAttribute(AnonymousType = true)]
		public class Definition
		{
			[XmlAttributeAttribute()]
			public string Title;
			[XmlAttributeAttribute()]
			public string Description;
			[XmlAttributeAttribute()]
			public string Goal;
		}

		[System.SerializableAttribute()]
		[XmlTypeAttribute(AnonymousType = true)]
		public partial class Users
		{
			[XmlElementAttribute("User", Form = System.Xml.Schema.XmlSchemaForm.Unqualified)]
			public User[] User;
		}

		[System.SerializableAttribute()]
		[XmlTypeAttribute(AnonymousType = true)]
		public class User
		{
			[XmlAttributeAttribute()]
			public string Name;
			[XmlElementAttribute("UserAchievement", Form = System.Xml.Schema.XmlSchemaForm.Unqualified)]
			public UserAchievement[] UserAchievement;
		}

		[System.SerializableAttribute()]
		[XmlTypeAttribute(AnonymousType = true)]
		public class UserAchievement
		{
			[XmlAttributeAttribute()]
			public string Title;
			[XmlAttributeAttribute()]
			public string Progress;
		}
	}
}