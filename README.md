## Known Issues

	* #1 PROBLEM: session events don't include user info! Just "host" info. So if a user sets a display name, we get that string instead of the actualy unique user name, which we were going to rely on
	* Updating the achievement definitions will be hard after the Extension is released. It's gonna take code to add them. That can get hairy... Maybe we can just add a web method to do it or something so that we can call it at any time
	* The extension doesn't use the security context or anything. Just gets user data based on the username. Assuming usernames are unique this should be fine. But anyone is really able to get or update anyone elses achievements. The key this in the triggers mitigates this

## Achievement Ideas

	* Made a Session Group
	* Added item to toolbox
	* Ran toolbox item (elevated)
	* Connected to Session
	* Customized resoures(web/app)
	* Created, Connected, and Ended certain # of support sessions
	* # of total Host Connections
	* # of connections for a single guest
	* Publish an extension
	* Edited database maintenance plan
	* Created one of each session type
	* Created a new role (admin only)
	* Set up new user source (admin only)
	* On-prem uptime
	* Sending feedback to the survey
