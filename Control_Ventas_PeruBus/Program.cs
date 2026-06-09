using Control_Ventas_PeruBus.Components;
using Control_Ventas_PeruBus.Data.Interfaces;
using Control_Ventas_PeruBus.Data.Repository;
using Control_Ventas_PeruBus.Services.Interfaces;
using Control_Ventas_PeruBus.Services.Repository;
using MudBlazor.Services;
using Microsoft.Extensions.DependencyInjection;

var builder = WebApplication.CreateBuilder(args);
var connectionStrting = builder.Configuration.GetConnectionString("konect");

// Add services to the container.
builder.Services.AddRazorComponents()
    .AddInteractiveServerComponents(options =>
    {
        options.DetailedErrors = true;
    });
builder.Services.AddMudServices();
builder.Services.AddControllers();
builder.Services.AddRazorPages();
builder.Services.AddServerSideBlazor(options =>
{
    options.DetailedErrors = true;
});
builder.Services.AddMudServices();
builder.Services.AddMemoryCache();
builder.Services.AddResponseCompression(options =>
{
    options.EnableForHttps = true;
});

// Dependency Injection registrations
builder.Services.AddScoped<IVentaRutaRepository, VentaRutaRepository>();
builder.Services.AddScoped<IVentaRutaService, VentaRutaService>();
builder.Services.AddScoped<IVentaAgenciaRepository, VentaAgenciaRepository>();
builder.Services.AddScoped<IVentaAgenciaService, VentaAgenciaService>();

var app = builder.Build();

// Configure the HTTP request pipeline.
if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Error", createScopeForErrors: true);
    app.UseHsts();
    app.UseHttpsRedirection();
}

app.UseResponseCompression();
app.UseStaticFiles();
app.UseAntiforgery();
app.UseWebSockets();

app.MapRazorComponents<App>()
    .AddInteractiveServerRenderMode();

app.MapControllers();

app.Run();
