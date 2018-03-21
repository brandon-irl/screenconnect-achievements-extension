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
		achievementsProvider = new XmlAchievementsProvider();
	}

	public object GetAchievementDefinitions()
	{
		return achievementsProvider.GetAllDefinitions();
	}

	public object GetUsers()
	{
		return achievementsProvider.GetAllUsers();
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

		return achievementsProvider.GetUserAchievements(username);
	}

	public object GetAchievementProgressForUser(string achievementTitle, string username)
	{
		achievementTitle.AssertArgumentNonNull();
		username.AssertArgumentNonNull();

		return achievementsProvider
				.GetUserAchievements(username)
				.Where(_ => _.Title == achievementTitle)
				.FirstOrDefault()
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
			new UserAchievement { Title = achievementTitle, Progress = progress },
			username
		);
	}

	private void VerifyKey(string key)
	{
		if (key != validationKey)
			throw new HttpException(403, "Not allowed to set achievements yourself");
	}

	//	*****************************************Helper Stuff*****************************************
	public abstract class AchievementsProvider
	{
		public abstract User[] GetAllUsers();
		public abstract Definition[] GetAllDefinitions();
		public abstract UserAchievement[] GetUserAchievements(string username);
		public abstract void UpdateUserAchievement(UserAchievement achievement, string username);
	}

	public class XmlAchievementsProvider : AchievementsProvider
	{
		static FileInfo GetAchievementsFile()
		{
			var path = ExtensionContext.Current.BasePath + @"\" + "Achievements.xml";
			return new FileInfo(path);
		}

		static Achievements TryLoadAchievements()
		{
			return ServerExtensions.DeserializeXml<Achievements>(GetAchievementsFile().FullName);
		}

		static void ModifyAchievementsXml(Proc<Achievements> proc)
		{
			var achievements = TryLoadAchievements() ?? new Achievements();
			proc(achievements);
			ServerExtensions.SafeSerializeXml(XmlAchievementsProvider.GetAchievementsFile().FullName, achievements);
		}

		Definition GetDefinition(string definitionTitle)
		{
			return TryLoadAchievements()
					.DefinitionCollection.Definitions
					.Where(_ => _.Title == definitionTitle)
					.FirstOrDefault();
		}

		public override Definition[] GetAllDefinitions()
		{
			return TryLoadAchievements()
					.SafeNav(_ => _.DefinitionCollection.Definitions)
					.ToArray();
		}

		public override User[] GetAllUsers()
		{
			return TryLoadAchievements()
					.SafeNav(_ => _.UserCollection.Users)
					.ToArray();
		}

		public User GetUser(string username)
		{
			var user = TryLoadAchievements()
					.UserCollection.Users
					.Where(_ => _.Name == username)
					.FirstOrDefault();

			if (user == null)
				user = EnsureUserExistsInXml(username);

			return user;
		}

		public override UserAchievement[] GetUserAchievements(string username)
		{
			return TryLoadAchievements()
					.UserCollection.Users
					.Where(_ => _.Name == username)
					.FirstOrDefault()
					.UserAchievements
					.ToArray();
		}

		public override void UpdateUserAchievement(UserAchievement achievement, string username)
		{
			CheckAchievementProgressAgainstDefinition(achievement);
			ModifyAchievementsXml((_ =>
			{
				var user = _.UserCollection.Users
					.Where(__ => __.Name == username)
					.FirstOrDefault();
				var existingAchievement = user
					.UserAchievements
					.Where(__ => __.Title == achievement.Title)
					.FirstOrDefault();
				if (existingAchievement != null)
					existingAchievement = achievement;
				else
					user.UserAchievements.Add(achievement);
			}));
		}

		private void CheckAchievementProgressAgainstDefinition(UserAchievement achievement)
		{
			var definition = GetDefinition(achievement.Title);
			if (definition == null)
				throw new ArgumentException(string.Format("Achievement '{0}' does not exist", achievement.Title));

			achievement.Achieved = achievement.Progress == definition.Goal;     //TODO: this isn't really going to work the way we want it to for most achievements. Need a way to tell this method what operator to use
		}

		private User EnsureUserExistsInXml(string username)
		{
			username.AssertArgumentNonNull();

			var user = new User { Name = username };
			ModifyAchievementsXml((_ => _.UserCollection.Users.Add(user)));
			return GetUser(username);
		}
	}

	[SerializableAttribute()]
	[XmlTypeAttribute(AnonymousType = true)]
	[XmlRootAttribute(Namespace = "", IsNullable = false)]
	public partial class Achievements
	{
		[XmlElementAttribute("Definitions", typeof(DefinitionCollection), Form = System.Xml.Schema.XmlSchemaForm.Unqualified)]
		public DefinitionCollection DefinitionCollection;
		[XmlElementAttribute("Users", typeof(UserCollection), Form = System.Xml.Schema.XmlSchemaForm.Unqualified)]
		public UserCollection UserCollection;
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
	public partial class DefinitionCollection
	{
		[XmlElementAttribute("Definition", Form = System.Xml.Schema.XmlSchemaForm.Unqualified)]
		public List<Definition> Definitions;
	}

	[System.SerializableAttribute()]
	[XmlTypeAttribute(AnonymousType = true)]
	public partial class UserCollection
	{
		[XmlElementAttribute("User", Form = System.Xml.Schema.XmlSchemaForm.Unqualified)]
		public List<User> Users;
	}

	[System.SerializableAttribute()]
	[XmlTypeAttribute(AnonymousType = true)]
	public class User
	{
		[XmlAttributeAttribute()]
		public string Name;
		[XmlElementAttribute("UserAchievement", Form = System.Xml.Schema.XmlSchemaForm.Unqualified)]
		public List<UserAchievement> UserAchievements;
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