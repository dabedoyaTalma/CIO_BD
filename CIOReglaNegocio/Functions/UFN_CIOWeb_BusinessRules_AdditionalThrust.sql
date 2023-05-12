/****** Object:  UserDefinedFunction [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_AdditionalThrust]    Script Date: 12/05/2023 15:25:28 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- ==================================================================================================================
-- Change History:
--	2019-12-10	Diomer Bedoya: Se agrega la base de RNG, Se cambia el tipo de actividad a traslado gate
--	2021-02-16	Sebastián Jaramillo: Se adiciona la columna centro de costos en la tabla retornada
--	2022-07-28	Sebastián Jaramillo: Se ajusta RN VivaColombia para indicar explícitamente servicios internacionales
-- ==================================================================================================================
--SELECT * FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_AdditionalThrust](3081,12,79,44,'233')
ALTER FUNCTION [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_AdditionalThrust](
	@ServiceHeaderId INT
,	@AirportId INT
,	@OriginId INT
,	@DestinationId INT
,	@CompanyId INT
,	@BillingToCompany INT
,	@AirplaneType NVARCHAR(50)
)
RETURNS @Result TABLE(ROW INT IDENTITY, StartHour DATETIME, EndHour DATETIME, AdditionalService BIT, AdditionalQuantity INT, AdditionalServiceName VARCHAR(150), CostCenter NVARCHAR(50))
AS
BEGIN
	DECLARE	@Service NVARCHAR(50) = 'EMPUJE / REMOLQUE'
	DECLARE	@ExtraText VARCHAR(50) = ''

	IF (@AirportId IN (10, 11, 17, 3, 4) AND @CompanyId = 44 AND @BillingToCompany = 44)
	BEGIN
		SET @Service = @Service + ' ' + LTRIM(RTRIM(@AirplaneType))
	END

	DECLARE		@ServiceDetail AS [CIOReglaNegocio].[ServiceDetailTypeExtended] --TIPO DEFINIDO
	INSERT		@ServiceDetail
	SELECT		ROW_NUMBER() OVER(ORDER BY DS.DetalleServicioId) [Fila],
				CONCAT(@Service, CASE WHEN P.NombrePropietario <> 'ATO' THEN CONCAT(' ', P.NombrePropietario) ELSE '' END) [Servicio],
				DS.FechaInicio [HoraInicio], 
				DS.FechaFin [HoraFinal], 
				DATEDIFF(MI, DS.FechaInicio, DS.FechaFin) [TiempoTotal], 
				ISNULL(DS.cantidad, 1) [Cantidad],
				P.NombrePropietario [NombrePropietario]
	FROM		CIOServicios.DetalleServicio DS
	LEFT JOIN	CIOServicios.Propietario P ON DS.PropietarioId = P.PropietarioId
	WHERE		DS.Activo = 1 AND
				DS.TipoActividadId = 49 AND --REMOLQUE ADICIONAL
				DS.EncabezadoServicioId = @ServiceHeaderId

	IF (SELECT SUM(cantidad) FROM @ServiceDetail) = 0 RETURN


	IF (@CompanyId = 60 AND @BillingToCompany = 90) --VIVA COLOMBIA                         
	BEGIN
	IF (CIOServicios.UFN_CIO_InternationalFlight(@AirportId, @DestinationId) = 1)
		BEGIN
			SET @ExtraText = ' INTERNACIONAL'
		END

		INSERT @Result SELECT StartTime, FinalTime, IsAdditionalService, AdditionalQuantity, CONCAT(AdditionalService, @ExtraText) AdditionalService, OwnerName AS CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_CalculateQuantityExtended](@ServiceDetail, 0)
		RETURN
	END

	IF (@CompanyId = 43 AND @BillingToCompany = 1) --AMERICAN AIRLINES A AVIANCA                        
	BEGIN
		INSERT @Result SELECT StartTime, FinalTime, IsAdditionalService, AdditionalQuantity, AdditionalService, OwnerName AS CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_CalculateQuantityExtended](@ServiceDetail, 2)
		RETURN
	END

	INSERT @Result SELECT StartTime, FinalTime, IsAdditionalService, AdditionalQuantity, AdditionalService, OwnerName AS CostCenter FROM [CIOReglaNegocio].[UFN_CIOWeb_CalculateQuantityExtended](@ServiceDetail, 0)
	RETURN
END