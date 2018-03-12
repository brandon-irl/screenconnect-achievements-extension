<%@ WebHandler Language="C#" Class="Service" %>

using System;
using System.Text;
using System.IO;
using System.Web;
using System.Linq;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using System.Xml;
using System.Xml.Linq;
using System.Xml.Serialization;
using ScreenConnect;

public class Service : WebServiceBase
{
	AchievementsProvider achievementsProvider;
	const string validationKey = "wXJSJ95g4Q2CZChNCW98";

	public Service()
	{
		achievementsProvider = new AchievementsProvider();
	}

	public object GetAchievementDefinitions()
	{
		return achievementsProvider.GetDefinitions();
	}

	public object GetUsers()
	{
		return achievementsProvider.GetUsers();
	}

	public async Task<object> GetAchievementDataForLoggedOnUserAsync(long version)
	{
		var newVersion = await WaitForChangeManager.WaitForChangeAsync(version, null);
		return new
		{
			Version = newVersion,
			Achievements = GetAchievementDataForLoggedOnUser() //TODO: figure out why this causes some calls to throw a null ref exception: \u003e (Inner Exception #0) System.NullReferenceException: Object reference not set to an instance of an object.\r\n   at ScreenConnect.ExtensionContext.get_Current() in C:\\compile\\ScreenConnect\\ScreenConnectWork\\cwcontrol\\Product\\Server\\Extension.cs:line 727\r\n   at Service.XmlProviderBase.TryReadObjectXml[TObject](Func`2 additionalValidator) in c:\\compile\\ScreenConnect\\ScreenConnectWork\\cwcontrol\\Product\\Site\\App_Extensions\\90d13a55-d971-4a00-8d9b-e6edb7262b2f\\Service.ashx:line 207\r\n   at Service.AchievementsProvider.GetUser(String username) in c:\\compile\\ScreenConnect\\ScreenConnectWork\\cwcontrol\\Product\\Site\\App_Extensions\\90d13a55-d971-4a00-8d9b-e6edb7262b2f\\Service.ashx:line 101\r\n   at Service.\u003cGetAchievementDataForLoggedOnUserAsync\u003ed__1.MoveNext() in c:\\compile\\ScreenConnect\\ScreenConnectWork\\cwcontrol\\Product\\Site\\App_Extensions\\90d13a55-d971-4a00-8d9b-e6edb7262b2f\\Service.ashx:line 53\u003c---\r\n
		};
	}

	public object GetAchievementDataForLoggedOnUser()
	{
		return GetAchievementDataForUser(HttpContext.Current.User.Identity.Name);
	}

	public object GetAchievementDataForUser(string username)
	{
		username.AssertArgumentNonNull();

		return achievementsProvider.GetUser(username);
	}

	public object GetAchievementProgressForUser(string achievementTitle, string username)
	{
		achievementTitle.AssertArgumentNonNull();
		username.AssertArgumentNonNull();

		return achievementsProvider
				.GetUserAchievement(achievementTitle, username)
				.SafeNav(_ => _.Progress);
	}

	public void UpdateAchievementForLoggedOnUser(string key, string achievementTitle, string progress)
	{
		UpdateAchievementForUser(key, achievementTitle, progress, HttpContext.Current.User.Identity.Name);
	}

	public void UpdateAchievementForUser(string key, string achievementTitle, string progress, string username)
	{
		VerifyKey(key);

		if (string.IsNullOrWhiteSpace(username))
			throw new ArgumentNullException("username");

		achievementsProvider.UpdateUserAchievement(
			new AchievementsProvider.UserAchievement { Title = achievementTitle, Progress = progress },
			achievementsProvider.GetUser(username)
		);
	}

	private void VerifyKey(string key)
	{
		if (key != validationKey)
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
			return TryReadObjectXml<Definition, Definitions>((_ => _.Title == definitionTitle));
		}

		public Definitions GetDefinitions()
		{
			return TryReadObjectXml<Definitions, Achievements>();
		}

		public User GetUser(string username)
		{
			var user = TryReadObjectXml<User, Users>((_ => _.Name == username));
			if (user == null)
				user = EnsureUserExistsInXml(username);

			return user;
		}

		public Users GetUsers()
		{
			return TryReadObjectXml<Users, Achievements>();
		}

		public UserAchievement GetUserAchievement(string achievementTitle, string username)
		{
			var userAchievement = TryReadObjectXml<UserAchievement, User>(
				(_ => _.Title == achievementTitle),
				(_ => _.Name == username)
			);

			if (userAchievement == null)
				userAchievement = EnsureUserAchievementExistsInXml(achievementTitle, username);

			return userAchievement;
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
			var definition = GetDefinition(achievement.Title);
			if (definition == null)
				throw new ArgumentException(string.Format("Achievement '{0}' does not exist", achievement.Title));

			achievement.Achieved = achievement.Progress == definition.Goal;     //TODO: this isn't really going to work the way we want it to for most achievements. Need a way to tell this method what operator to use
		}

		private UserAchievement EnsureUserAchievementExistsInXml(string achievementTitle, string username)
		{
			achievementTitle.AssertArgumentNonNull();
			username.AssertArgumentNonNull();

			var userAchievement = new UserAchievement() { Title = achievementTitle };
			WriteOrUpdateObjectXml<UserAchievement, User>(
				userAchievement,
				(_ => _.Title == achievementTitle),
				(_ => _.Name == username)
			);
			return userAchievement;
		}

		private User EnsureUserExistsInXml(string username)
		{
			username.AssertArgumentNonNull();

			var user = new User { Name = username };
			WriteOrUpdateObjectXml<User, Users>(
				user,
				(_ => _.Name == username)
			);
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
			[XmlAttributeAttribute()]
			public string EventFilter;
			[XmlAttributeAttribute()]
			public bool HiddenUntilAchieved;
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

		protected TObject TryReadObjectXml<TObject, KParent>(ScreenConnect.Func<TObject, bool> additionalValidator = null, ScreenConnect.Func<KParent, bool> parentValidator = null)
		{
			var objectName = typeof(TObject).Name;
			try
			{
				var xdoc = XDocument.Load(xmlPath);
				return FromXElement<TObject>(xdoc.Descendants(typeof(TObject).Name)
					.Where(_ => additionalValidator != null ? additionalValidator(FromXElement<TObject>(_)) : true)        // TODO: find a way to only call FromXElement once
					.Where(_ => parentValidator != null ? parentValidator(FromXElement<KParent>(_.Parent)) : true)
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

		protected void WriteObjectXml<TObject, KParent>(TObject obj, ScreenConnect.Func<KParent, bool> parentValidator = null)
		{
			try
			{
				EditXml((xdoc) =>
				{
					var parentElement = xdoc.Descendants(typeof(KParent).Name)
							.Where(_ => parentValidator != null ? parentValidator(FromXElement<KParent>(_)) : true)
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

		protected void UpdateObjectXml<TObject, KParent>(TObject newObj, ScreenConnect.Func<TObject, bool> existingObjectValidator, ScreenConnect.Func<KParent, bool> parentValidator = null)
		{
			try
			{
				EditXml((xdoc) => xdoc.Descendants(typeof(TObject).Name)
									.Where(_ => existingObjectValidator(FromXElement<TObject>(_)))
									.Where(_ => parentValidator != null ? parentValidator(FromXElement<KParent>(_.Parent)) : true)
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

		protected void WriteOrUpdateObjectXml<TObject, KParent>(TObject obj, ScreenConnect.Func<TObject, bool> objectValidator, ScreenConnect.Func<KParent, bool> parentValidator = null)
		{
			var item = TryReadObjectXml<TObject, KParent>(objectValidator, parentValidator);
			if (item != null)
				UpdateObjectXml<TObject, KParent>(obj, objectValidator, parentValidator);
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