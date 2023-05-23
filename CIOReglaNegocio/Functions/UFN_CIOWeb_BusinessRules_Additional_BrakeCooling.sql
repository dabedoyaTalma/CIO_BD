/****** Object:  UserDefinedFunction [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_Additional_BrakeCooling]    Script Date: 23/05/2023 15:13:57 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- ============================================================================================================================================================================
-- Description: Function for Businees Rules "BrakeCooling"
-- Change History:
--	2022-06-14  Sebastián Jaramillo: Funtion created
--	2023-02-13	Sebastián Jaramillo: Se configura nuevo contrato de Avianca 2023 "TAKE OFF 20230201" y Regional Express se integra como un "facturar a" más de Avianca
--	2023-04-20	Sebastián Jaramillo: Fusión TALMA-SAI BOGEX Incorporación RN AVA estaciones (BGA, MTR, PSO, IBE, NVA) Compañía: Avianca - Facturar a: SAI
--	2023-05-23	Diomer Bedoya	   : Fusión TALMA-SAI AIR CENTURY Compañía: AIR CENTURY - Facturar a: SAI
-- ============================================================================================================================================================================
ALTER FUNCTION [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_Additional_BrakeCooling](
	@ServiceHeaderId BIGINT,
	@AirportId INT,
	@CompanyId INT,
	@BillingToCompany INT,
	@ServiceTypeId INT,
	@DateService DATE
)
--RETURNS @Result TABLE (cantidad FLOAT, ds_servicio NVARCHAR(50))
RETURNS @T_Result TABLE(ROW INT IDENTITY, StartDate DATETIME, EndDate DATETIME, Time INT, AdditionalService BIT, AdditionalStartHour DATETIME, AdditionalEndHour DATETIME, AdditionalTime INT, AdditionalQuantity INT, AdditionalServiceName VARCHAR(150), Fraction VARCHAR(25), TimeLeftover INT)
AS
BEGIN
	DECLARE		@TimeLeftover FLOAT=0

	DECLARE		@ServiceDetail AS CIOReglaNegocio.ServiceDetailType --TIPO DEFINIDO
	INSERT		@ServiceDetail
	SELECT		ROW_NUMBER() OVER(ORDER BY DS.DetalleServicioId) fila,
				'ENFRIAMIENTO DE FRENOS',
				DS.FechaInicio, 
				DS.FechaFin, 
				DATEDIFF(MI, DS.FechaInicio, DS.FechaFin) tiempo_total, 
				ISNULL(DS.cantidad, 1)
	FROM		CIOServicios.DetalleServicio DS
	WHERE		DS.Activo = 1 AND
				DS.TipoActividadId = 238 AND --ENFRIAMIENTO DE FRENOS
				DS.EncabezadoServicioId = @ServiceHeaderId

	IF (SELECT SUM(TiempoTotal) FROM @ServiceDetail) = 0 RETURN

	--AIR CENTURY / SAI
	IF (@CompanyId=296 AND @BillingToCompany=87)
	BEGIN
		INSERT @T_Result SELECT StartTime, FinalTime, NULL, IsAdditionalService, StartTime, FinalTime, NULL, AdditionalAmount, AdditionalService, NULL, NULL FROM [CIOServicios].[UFN_CIOWeb_CalculateQuantity](@ServiceDetail, 0) WHERE AdditionalAmount > 0
		RETURN
	END


	 --AVIANCA / SAI
	IF (@CompanyId = 1 AND @BillingToCompany = 87)
	BEGIN
		IF (@DateService >= '2023-04-19' AND @AirportId IN (11, 40, 47, 31, 43)) --BGA, MTR, PSO, IBE, NVA
		BEGIN
			INSERT @T_Result SELECT StartTime, FinalTime, NULL, IsAdditionalService, StartTime, FinalTime, NULL, AdditionalAmount, AdditionalService, NULL, NULL FROM [CIOServicios].[UFN_CIOWeb_CalculateQuantity](@ServiceDetail, 0) WHERE AdditionalAmount > 0

			RETURN
		END
	END

	--AVIANCA S.A / AVIANCA S.A
	IF (@CompanyId=1 AND @BillingToCompany=1)
	BEGIN
		IF (@DateService >= '2022-06-01')
		BEGIN
			INSERT @T_Result SELECT StartTime, FinalTime, NULL, IsAdditionalService, StartTime, FinalTime, NULL, AdditionalAmount, AdditionalService, NULL, NULL FROM [CIOServicios].[UFN_CIOWeb_CalculateQuantity](@ServiceDetail, 0) WHERE AdditionalAmount > 0
		END
	END

	--AVIANCA S.A / REGIONAL EXPRESS
	IF (@CompanyId=1 AND @BillingToCompany=193)
	BEGIN
		IF (@DateService >= '2023-02-01')
		BEGIN
			INSERT @T_Result SELECT StartTime, FinalTime, NULL, IsAdditionalService, StartTime, FinalTime, NULL, AdditionalAmount, AdditionalService, NULL, NULL FROM [CIOServicios].[UFN_CIOWeb_CalculateQuantity](@ServiceDetail, 0) WHERE AdditionalAmount > 0
		END
	END

	--TACA / AVIANCA S.A
	IF (@CompanyId=42 AND @BillingToCompany=1)
	BEGIN
		IF (@DateService >= '2023-02-01')
		BEGIN
			INSERT @T_Result SELECT StartTime, FinalTime, NULL, IsAdditionalService, StartTime, FinalTime, NULL, AdditionalAmount, AdditionalService, NULL, NULL FROM [CIOServicios].[UFN_CIOWeb_CalculateQuantity](@ServiceDetail, 0) WHERE AdditionalAmount > 0
		END
	END

	--AEROGAL / AVIANCA S.A
	IF (@CompanyId=47 AND @BillingToCompany=1)
	BEGIN
		IF (@DateService >= '2023-02-01')
		BEGIN
			INSERT @T_Result SELECT StartTime, FinalTime, NULL, IsAdditionalService, StartTime, FinalTime, NULL, AdditionalAmount, AdditionalService, NULL, NULL FROM [CIOServicios].[UFN_CIOWeb_CalculateQuantity](@ServiceDetail, 0) WHERE AdditionalAmount > 0
		END
	END

	RETURN
END