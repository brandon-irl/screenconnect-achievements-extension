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
using ScreenConnect;

public class Service : WebServiceBase
{
	AchievementsProvider achievementsProvider;

	public Service()
	{
		this.achievementsProvider = new AchievementsProvider();
	}

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
		return this.achievementsProvider.GetDefinitions();
	}

	public object GetUsers()
	{
		return this.achievementsProvider.GetUsers();
	}

	public async Task<object> GetAchievementDataForLoggedOnUserAsync(long version)
	{
		var newVersion = await WaitForChangeManager.WaitForChangeAsync(version, null);
		return new
		{
			Version = newVersion,
			Achievements = this.GetAchievementDataForLoggedOnUser() //TODO: figure out why this causes some calls to throw a null ref exception: \u003e (Inner Exception #0) System.NullReferenceException: Object reference not set to an instance of an object.\r\n   at ScreenConnect.ExtensionContext.get_Current() in C:\\compile\\ScreenConnect\\ScreenConnectWork\\cwcontrol\\Product\\Server\\Extension.cs:line 727\r\n   at Service.XmlProviderBase.TryReadObjectXml[TObject](Func`2 additionalValidator) in c:\\compile\\ScreenConnect\\ScreenConnectWork\\cwcontrol\\Product\\Site\\App_Extensions\\90d13a55-d971-4a00-8d9b-e6edb7262b2f\\Service.ashx:line 207\r\n   at Service.AchievementsProvider.GetUser(String username) in c:\\compile\\ScreenConnect\\ScreenConnectWork\\cwcontrol\\Product\\Site\\App_Extensions\\90d13a55-d971-4a00-8d9b-e6edb7262b2f\\Service.ashx:line 101\r\n   at Service.\u003cGetAchievementDataForLoggedOnUserAsync\u003ed__1.MoveNext() in c:\\compile\\ScreenConnect\\ScreenConnectWork\\cwcontrol\\Product\\Site\\App_Extensions\\90d13a55-d971-4a00-8d9b-e6edb7262b2f\\Service.ashx:line 53\u003c---\r\n
		};
	}

	public object GetAchievementDataForLoggedOnUser()
	{
		return this.achievementsProvider.GetUser(HttpContext.Current.User.Identity.Name);
	}

	public void UpdateAchievementForLoggedOnUser(string key, string achievementTitle, string progress)
	{
		this.UpdateAchievementForUser(key, achievementTitle, progress, HttpContext.Current.User.Identity.Name);
	}

	public void UpdateAchievementForUser(string key, string achievementTitle, string progress, string username)
	{
		VerifyKey(key);

		if (string.IsNullOrWhiteSpace(username))
			throw new ArgumentNullException("username");

		this.achievementsProvider.UpdateUserAchievement(
			new AchievementsProvider.UserAchievement { Title = achievementTitle, Progress = progress },
			this.achievementsProvider.GetUser(username)
		);
	}

	private void VerifyKey(string key)
	{
		if (key != "wXJSJ95g4Q2CZChNCW98")
			throw new HttpException(403, "Not allowed to set achievements yourself");
	}

	//	*****************************************Helper Stuff*****************************************
	public class AchievementsProvider : XmlProviderBase
	{
		protected override string xmlPath
		{
			get
			{
				return ExtensionContext.Current.BasePath + @"\" + "Achievements.xml";
			}
		}

		public Definition GetDefinition(string definitionTitle)
		{
			return TryReadObjectXml<Definition>((_ => _.Title == definitionTitle));
		}

		public Definitions GetDefinitions()
		{
			return TryReadObjectXml<Definitions>();
		}

		public User GetUser(string username)
		{
			var user = TryReadObjectXml<User>((_ => _.Name == username));
			if (user == null)
			{
				user = EnsureUserExistsInXml(username);
			}
			return user;
		}

		public Users GetUsers()
		{
			return TryReadObjectXml<Users>();
		}

		public void UpdateUserAchievement(UserAchievement achievement, User user)
		{
			CheckAchievementProgressAgainstDefinition(achievement);
			WriteOrUpdateObjectXml<UserAchievement, User>(
				achievement,
				(_ => _.Title == achievement.Title),
				(_ => _.Name == user.Name)
			);
		}

		private void CheckAchievementProgressAgainstDefinition(UserAchievement achievement)
		{
			var definition = this.GetDefinition(achievement.Title);
			if (definition == null)
				throw new ArgumentException(string.Format("Achievement '{0}' does not exist", achievement.Title));

			achievement.Achieved = achievement.Progress == definition.Goal;		//TODO: this isn't really going to work the way we want it to for most achievements. Need a way to tell this method what operator to use
		}

		private User EnsureUserExistsInXml(string username)
		{
			var user = new User { Name = username };
			WriteObjectXml<User, Users>(user);
			return GetUser(username);
		}

		protected override void EnsureXmlExists()
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
			[XmlAttributeAttribute()]
			public string Image;
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
			[XmlAttributeAttribute()]
			public bool Achieved;
		}
	}

	public abstract class XmlProviderBase
	{
		protected abstract string xmlPath { get; }

		protected TObject TryReadObjectXml<TObject>()
		{
			return TryReadObjectXml<TObject>((_ => true));
		}

		protected TObject TryReadObjectXml<TObject>(ScreenConnect.Func<TObject, bool> additionalValidator)
		{
			var objectName = typeof(TObject).Name;
			try
			{
				var xdoc = XDocument.Load(xmlPath);
				return FromXElement<TObject>(xdoc.Descendants(typeof(TObject).Name)
					.Where(_ => additionalValidator(FromXElement<TObject>(_)))        // TODO: find a way to only call FromXElement once
					.FirstOrDefault());
			}
			catch (FileNotFoundException)
			{
				EnsureXmlExists();
			}
			catch (Exception ex)
			{
				// TODO: something
			}
			return default(TObject);
		}

		protected void WriteObjectXml<TObject, KParent>(TObject obj)
		{
			WriteObjectXml<TObject, KParent>(obj, (_ => true));
		}

		protected void WriteObjectXml<TObject, KParent>(TObject obj, ScreenConnect.Func<KParent, bool> parentValidator)
		{
			try
			{
				EditXml((xdoc) =>
				{
					var parentElement = xdoc.Descendants(typeof(KParent).Name)
							.Where(_ => parentValidator(FromXElement<KParent>(_)))
							.FirstOrDefault();
					if (parentElement != null)
						parentElement.Add(ToXElement<TObject>(obj));
					else
						throw new ArgumentException(string.Format("Could not find specified parent ({0}) in XML", typeof(KParent).Name));
				}
				);
			}
			catch (FileNotFoundException)
			{
				EnsureXmlExists();
			}
			catch (Exception ex)
			{
				// TODO: something
			}
		}

		protected void UpdateObjectXml<TObject>(TObject newObj, ScreenConnect.Func<TObject, bool> existingObjectValidator)
		{
			try
			{
				EditXml((xdoc) => xdoc.Descendants(typeof(TObject).Name)
									.Where(_ => existingObjectValidator(FromXElement<TObject>(_)))
									.FirstOrDefault()
									.SafeDo(_ => _.ReplaceWith(ToXElement<TObject>(newObj)))
				);
			}
			catch (FileNotFoundException)
			{
				EnsureXmlExists();
			}
			catch (Exception ex)
			{
				// TODO: something
			}
		}

		protected void WriteOrUpdateObjectXml<TObject, KParent>(TObject obj, ScreenConnect.Func<TObject, bool> objectValidator, ScreenConnect.Func<KParent, bool> parentValidator)
		{
			var item = TryReadObjectXml<TObject>(objectValidator);
			if (item != null)
				UpdateObjectXml<TObject>(obj, objectValidator);
			else
				WriteObjectXml<TObject, KParent>(obj, parentValidator);
		}

		protected TObject Deserialize<TObject>(XmlReader xmlReader)
		{
			var serilalizer = new XmlSerializer(typeof(TObject));
			return (TObject)serilalizer.Deserialize(xmlReader);
		}

		protected XElement ToXElement<TObject>(object obj)
		{
			using (var memoryStream = new MemoryStream())
			{
				using (TextWriter streamWriter = new StreamWriter(memoryStream))
				{
					var xmlSerializer = new XmlSerializer(typeof(TObject));
					xmlSerializer.Serialize(streamWriter, obj);
					return XElement.Parse(Encoding.ASCII.GetString(memoryStream.ToArray()));
				}
			}
		}

		protected TObject FromXElement<TObject>(XElement xElement)
		{
			return Deserialize<TObject>(xElement.CreateReader());
		}

		protected void EditXml(Proc<XDocument> proc)
		{

			var xdoc = XDocument.Load(xmlPath);
			proc(xdoc);
			xdoc.Save(xmlPath);
		}
		protected abstract void EnsureXmlExists();
	}
}