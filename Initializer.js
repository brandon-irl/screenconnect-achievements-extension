SC.event.addGlobalHandler(SC.event.ExecuteCommand, function (eventArgs) {
	switch (eventArgs.commandName) {
		case 'viewAchievements':
			//SC.dialog.showModalPage(SC.res['Achievements.AchievementText'],
			//	'Achievements.aspx',
			//	null
			//);

			//SC.service.GetAchievementDataForLoggedOnUser(function (result) {
			//	SC.dialog.showModalDialog(
			//		'Prompt',
			//		SC.res['Achievements.AchievementText'],
			//		[
			//			SC.dialog.createTitlePanel(SC.res['Achievements.AchievementText']),
			//			SC.ui.createElement('p', JSON.stringify(result))
			//		]
			//	);
			//});
			SC.pagedata.startPageDataLoop(function (version, onSuccess, onFailure) {
				return SC.service.GetAchievementDataForLoggedOnUserAsync(version, function (result) {
					console.log(result);
				});
			});


			break;
	}
});

SC.event.addGlobalHandler(SC.event.QueryCommandButtons, function (eventArgs) {
	switch (eventArgs.area) {
		case 'ExtrasPopoutPanel':
			eventArgs.buttonDefinitions.push({ commandName: 'viewAchievements', text: SC.res['Achievements.AchievementText'], className: 'AlwaysOverflow' });
			break;
	}
});