// Adds the "SnackBar" div to the page
SC.event.addGlobalHandler(SC.event.PreRender, function () {
	SC.util.includeStyleSheet(extensionContext.baseUrl + 'Style.css');

	$('.OuterPanel').appendChild($div({ id: 'SnackBar' }));
});

var showSnackBarWithMessage = function (message) {
	var sb = $('#SnackBar')
	SC.ui.setInnerText(sb, message);
	sb.className = "show";
	setTimeout(function () { sb.className = sb.className.replace("show", ""); }, 3000);;
}

// Polls for the User Achievement data
SC.event.addGlobalHandler(SC.event.PostRender, function () {
	var version = 0;
	var pendingRequest = null;
	var proc = function (version) {
		if (!SC.ui.isWindowActive()) {
			window.setTimeout(function () {
				proc(version);
			}, 1000);
		} else {
			pendingRequest = SC.service.GetAchievementDataForLoggedOnUserAsync(
				version,
				function (result) {
					version = result.Version;
					console.log("AchievementDataForLoggedOnUser: " + JSON.stringify(result));
					
					if (window.userAchievementData && window.userAchievementData != result)
						showSnackBarWithMessage(SC.res['Achievements.NewAchievementSnackbarMessage']);

					window.userAchievementData = result;

					proc(version);
				},
				function (error) {
					var shouldShowError = (error.errorType !== 'TimeoutException')
					window.setTimeout(function () {
						if (shouldShowError)
							SC.dialog.hideModalDialog();

						proc(version);
					}, 10000);
				}
			)
		}
	};

	SC.event.addGlobalHandler(SC.event.PageDataDirtied, function () {
		if (pendingRequest) {
			pendingRequest.abort();
			pendingRequest = null;
		}
		proc(version);
	});

	proc(version);
});

// Adds "Achievements" button to the Extras menu
SC.event.addGlobalHandler(SC.event.QueryCommandButtons, function (eventArgs) {
	switch (eventArgs.area) {
		case 'ExtrasPopoutPanel':
			eventArgs.buttonDefinitions.push({ commandName: 'ViewAchievements', text: SC.res['Achievements.AchievementText'], className: 'AlwaysOverflow' });
			// eventArgs.buttonDefinitions.push({ commandName: 'TestAchievementMessage', text: 'Test Achievement Message', className: 'AlwaysOverflow' });
			break;
	}
});

// Handles "ViewAchievements" command and show Achievements modal
SC.event.addGlobalHandler(SC.event.ExecuteCommand, function (eventArgs) {
	switch (eventArgs.commandName) {
		case 'TestAchievementMessage':
			showSnackBarWithMessage("This is only a test");
			break;
		case 'ViewAchievements':
			SC.service.GetAchievementDefinitions(function (result) {
				console.log("AchievementDefinitions: " + JSON.stringify(result));

				var achievementsPanel = $div({ id: 'AchievementsPanel' },
					result.Definition.map(function (def) {
						var userAchievement = window.userAchievementData.Achievements.UserAchievement ?
							window.userAchievementData.Achievements.UserAchievement.filter(function (ach) { return ach.Title === def.Title; })[0] :
							null;
						var defPanel = $div({ id: 'DefinitionPanel' },
							[
								def.Title,
								$p(def.Description),
								$div({ className: 'Circle' },
									[$img({ className: 'trophyImage', src: SC.ui.createDataUri(def.Image) })]
								)
							]
						);

						SC.ui.setVisible(defPanel, !def.HiddenUntilAchieved);
						SC.css.ensureClass(defPanel, 'HasAchieved', userAchievement ? userAchievement.Achieved : false);
						return defPanel;
					})
				);

				SC.dialog.showModalButtonDialog(
					"ViewAchievements",
					SC.context.userDisplayName === null ? SC.res['Achievements.AchievementText'] : SC.util.formatString(SC.res['Achievements.ViewAchievementsTitle'], SC.context.userDisplayName),
					SC.res['Achievements.ViewAchievementsButtonText'],
					"Close",		// buttonCommandName
					function (container) {	// contentBuilderProc
						SC.ui.setContents(container,
							[
								achievementsPanel
							]
						);
					},
					null,	// onExecuteCommandProc
					null	//onQueryCommandButtonStateProc
				);

			});

			break;
	}
});
