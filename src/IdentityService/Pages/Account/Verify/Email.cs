using Microsoft.Extensions.Options;
using System.Net.Mail;
using System.Threading.Tasks;

public class EmailConfig
{
    public string Name { get; set; }
    public string Email { get; set; }
    public string Host { get; set; }
    public int Port { get; set; }
    public string Username { get; set; }
    public string Password { get; set; }
    public bool EnableSsl { get; set; }
}

// IEmailSender là một giao diện cung cấp hàm SendEmailAsync
public interface IEmailSender
{
    Task SendEmail(string email, string subject, string message);
}

// EmailSender có hàm SendEmailAsync gửi email chứa OTP
public class EmailSender : IEmailSender
{
    private readonly EmailConfig _emailConfig;

    public EmailSender(IOptions<EmailConfig> emailConfig)
    {
        _emailConfig = emailConfig.Value;
    }

    public async Task SendEmail(string email, string subject, string message)
    {
        MailMessage mail = new MailMessage
        {
            From = new MailAddress(_emailConfig.Email, _emailConfig.Name),
            Subject = subject,
            Body = message,
            IsBodyHtml = true
        };
        mail.To.Add(email);

        using SmtpClient _sender = new SmtpClient(_emailConfig.Host, _emailConfig.Port)
        {
            Credentials = new System.Net.NetworkCredential(_emailConfig.Username, _emailConfig.Password),
            EnableSsl = _emailConfig.EnableSsl,
            Timeout = 3000
        };

        await _sender.SendMailAsync(mail);
    }
}
