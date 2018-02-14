<%@ Page Language="C#" MasterPageFile="~/Default.master" ClassName="ScreenConnect.AchievementsPage"%>

<asp:Content runat="server" ContentPlaceHolderID="RunScript">
<script>
SC.service.GetAchievementData("", function (result) {
	SC.dialog.showModalMessageBox('Achievements', 'This is where achievements will be shown' + "\n" + JSON.stringify(result));
});
</script>
</asp:Content>