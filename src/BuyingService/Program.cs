using BuyingService;
using MassTransit;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using MongoDB.Driver;
using MongoDB.Entities;
using Polly;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddTransient<IEmailSender, EmailSender>();


builder.Services.AddControllers();

builder.Services.AddMassTransit(x =>
{
    x.AddConsumersFromNamespaceContaining<OrderCreatedConsumer>();


    x.SetEndpointNameFormatter(new KebabCaseEndpointNameFormatter("bids", false));
    x.UsingRabbitMq((context, cfg) =>
    {

        //Thêm để dùng khi chạy Dockerfile
        cfg.Host(builder.Configuration["RabbitMq:Host"], "/", host =>
        {
            host.Username(builder.Configuration.GetValue("RabbitMq:Username", "guest"));
            host.Password(builder.Configuration.GetValue("RabbitMq:Password", "guest"));
        });

        cfg.ConfigureEndpoints(context);
    });
});


builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)

    .AddJwtBearer(option =>
    {

        option.Authority = builder.Configuration["IdentityServiceUrl"];


        option.RequireHttpsMetadata = false;


        option.TokenValidationParameters.ValidateAudience = false;

        option.TokenValidationParameters.NameClaimType = "username";
        // option.TokenValidationParameters.NameClaimType = "email";
    });
builder.Services.AddEndpointsApiExplorer();


builder.Services.AddAutoMapper(AppDomain.CurrentDomain.GetAssemblies());



var app = builder.Build();





app.UseAuthorization();

app.MapControllers();


await Policy.Handle<TimeoutException>()
    .WaitAndRetryAsync(5, retryAttempt => TimeSpan.FromSeconds(10))
    .ExecuteAndCaptureAsync(async () =>
    {
        // Khởi tạo MongoDB.Entities
        await DB.InitAsync("BuyingDb", MongoClientSettings.FromConnectionString(builder.Configuration.GetConnectionString("BuyingDbConnection")));

    });

// await DB.InitAsync("BuyingDb", MongoClientSettings.FromConnectionString(builder.Configuration.GetConnectionString("BuyingDbConnection")));

app.Run();