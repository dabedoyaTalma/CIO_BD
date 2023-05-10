/****** Object:  UserDefinedFunction [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_Additional_TankingWithPassengersOnBoard]    Script Date: 09/05/2023 16:28:17 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- ==============================================================================================================================================================================
-- Description: Function for Businees Rules "Burder (Carga) or Discharging (Descarga)"
-- Returns:    
--
-- Change History:
--  2020-03-10  Amilkar Martínez: Funtion created
--  2022-01-06  Amilkar Martínez: Se comenta regla para AVA, por solicitud de facturación, con AVA están renegociando y se suspende el cobro
--	2022-02-10	Sebastián Jaramillo: Nueva RN Ultra Air
--	2022-02-17	Sebastián Jaramillo: Ajuste RN Ultra Air por servicio
--	2022-11-11	Sebastián Jaramillo: Se incluye RN para el cliente Aerolineas Argentinas
--	2023-04-20	Sebastián Jaramillo: Fusión TALMA-SAI BOGEX Incorporación RN AVA estaciones (BGA, MTR, PSO, IBE, NVA) Compañía: Avianca - Facturar a: SAI
--	2023-04-30	Sebastián Jaramillo: Se retira cobro de tanqueo con PAX a bordo, confirmado con Claudia por cambio en figura operacional con personal de LIMPIEZA
--	2023-05-09	Diomer Bedoya	   : Se incluye RN TALMA-SAI SPIRIT  Compañía: SPIRIT - Facturar a: SAI
-- ==============================================================================================================================================================================

-- SELECT * FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_TankingWithPassengersOnBoard] (1228297,1,304,1,1,0)	
ALTER FUNCTION [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_Additional_TankingWithPassengersOnBoard]
(	
    @ServiceHeaderId BIGINT,
	@ServiceTypeId INT,
	@ActivityTypeId INT,
	@AirportId NUMERIC(18,0),
	@CompanyId NUMERIC(18,0),
	@BillingToCompany INT	
)
RETURNS @T_Result TABLE([Row] INT Identity(1,1) , StartDate DATETIME, EndDate DATETIME, AdditionalQuanty INT, AdditionalServiceName VARCHAR(150))			
AS
BEGIN

  	DECLARE @ServiceDetail AS CIOReglaNegocio.ServiceDetailType--TIPO DEFINIDO

	--TANQUEO PAX A BORDO = 304
	IF(@ActivityTypeId = 304)
	BEGIN
		INSERT	@ServiceDetail
		SELECT	ROW_NUMBER() OVER(ORDER BY DS.DetalleServicioId) fila,
				'TANQUEO PAX A BORDO',
				DS.FechaInicio, 
				DS.FechaFin, 
				DATEDIFF(MI, DS.FechaInicio, DS.FechaFin) TotalTime, 
				ISNULL(DS.cantidad, 1) Cantidad
		FROM	CIOServicios.DetalleServicio DS
		WHERE	DS.Activo = 1 AND
				DS.TipoActividadId = @ActivityTypeId AND
				DS.EncabezadoServicioId = @ServiceHeaderId 
	END

	--IF(@ServiceTypeId IN (1,23) /*Transito, pernocta*/ AND @CompanyId = 1 /*Avianca*/  AND @AirportId IN (3,4) ) --MDE y CLO	
	--BEGIN 	 							 				
	--	INSERT @T_Result 
	--	SELECT HoraInicio, HoraFinal, TiempoTotal, Servicio FROM @ServiceDetail

	--	RETURN 
	--END

	--IF (@CompanyId = 1 AND @BillingToCompany = 87) --AVIANCA A SAI
	--BEGIN
	--	IF (@AirportId IN (11, 40, 47, 31, 43)) --BGA, MTR, PSO, IBE, NVA
	--	BEGIN
	--		INSERT @T_Result
	--		SELECT StartTime, FinalTime, AdditionalAmount, AdditionalService FROM [CIOServicios].[UFN_CIOWeb_CalculateQuantity](@ServiceDetail, 0) WHERE IsAdditionalService = 1

	--		RETURN
	--	END
	--END
		
	IF (@CompanyId=195 AND @BillingToCompany=87) --SPIRIT / SAI
	BEGIN
		INSERT @T_Result
		SELECT StartTime, FinalTime, AdditionalAmount, AdditionalService FROM [CIOServicios].[UFN_CIOWeb_CalculateQuantity](@ServiceDetail, 0) WHERE IsAdditionalService = 1
		RETURN
	END

	IF (@CompanyId = 67 AND @BillingToCompany = 67) --AEROLINEAS ARGENTINAS / AEROLINEAS ARGENTINAS
	BEGIN
		INSERT @T_Result
		SELECT StartTime, FinalTime, AdditionalAmount, AdditionalService FROM [CIOServicios].[UFN_CIOWeb_CalculateQuantity](@ServiceDetail, 0) WHERE IsAdditionalService = 1

		RETURN
	END

	IF (@CompanyId = 259 AND @BillingToCompany = 259) --ULTRA AIR / ULTRA AIR
	BEGIN
		INSERT @T_Result
		--SELECT HoraInicio, HoraFinal, TiempoTotal, Servicio FROM @ServiceDetail
		SELECT StartTime, FinalTime, AdditionalAmount, AdditionalService FROM [CIOServicios].[UFN_CIOWeb_CalculateQuantity](@ServiceDetail, 0) WHERE IsAdditionalService = 1

		RETURN
	END

	IF (@CompanyId = 228 AND @BillingToCompany = 228) --GRAN COLOMBIA DE AVIACION (GCA) A GRAN COLOMBIA DE AVIACION (GCA)
	BEGIN
		INSERT @T_Result
		SELECT HoraInicio, HoraFinal, TiempoTotal, Servicio FROM @ServiceDetail

		RETURN
	END
		
	RETURN
END