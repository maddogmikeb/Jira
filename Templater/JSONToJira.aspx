<%@ Page Language="C#" Debug="true" %>

<%@ Import Namespace="System.Net" %>
<%@ Import Namespace="System.IO" %>

<% Response.ContentType = "application/json"; %>
<% Response.AddHeader("Access-Control-Allow-Origin", "*"); %> 
<% Response.AddHeader("Access-Control-Allow-Methods", "POST, GET, OPTIONS, PUT, DELETE"); %> 

<script runat="server">

    protected override void OnLoad(EventArgs e)
    {
        string url = Server.UrlDecode(Request.QueryString["url"]);		
        if (string.IsNullOrEmpty(url))
        {
            return;
        }

		string jsonString = "";
		
        try
        {			
			HttpContext.Current.Request.InputStream.Position = 0;
			using (StreamReader inputStream = new StreamReader(this.Request.InputStream))
			{
				jsonString = inputStream.ReadToEnd();
			}
		
            var webClient = (HttpWebRequest)System.Net.WebRequest.Create(url);
            {
                string credentials = Convert.ToBase64String(Encoding.ASCII.GetBytes("UE00955" + ":" + "Passw0rd$%"));
                webClient.Headers[HttpRequestHeader.Authorization] = "Basic " + credentials;
		
				webClient.Accept = "application/json";
				webClient.ContentType = "application/json";
				webClient.Method = Request.HttpMethod;
		
				ASCIIEncoding encoding = new ASCIIEncoding();
				Byte[] bytes = encoding.GetBytes(jsonString);

				Stream newStream = webClient.GetRequestStream();
				newStream.Write(bytes, 0, bytes.Length);
				newStream.Close();

				var response = webClient.GetResponse();

				var stream = response.GetResponseStream();
				var sr = new StreamReader(stream);
				var content = sr.ReadToEnd();
		
                Response.Write(content);
				Response.StatusCode = 200;
            }
        }
        catch (Exception ex)
        {			
			Response.Write(url);
			Response.Write(Environment.NewLine);
			Response.Write(jsonString);
			Response.Write(Environment.NewLine);
			Response.Write(Environment.NewLine);			
            Response.Write(ex.ToString());
			Response.StatusCode = 600;
        }
    }

</script>