/****** Object:  UserDefinedFunction [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_Additional_CertifiedOfficeService]    Script Date: 10/05/2023 9:54:45 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================================================================================================================================================	
-- Description: Function for Businees Rules "CertifiedOfficeService"
-- Change History:
--	2023-05-09	Sebastián Jaramillo: Funtion created proyecto TALMA-SAI BOGEX
-- =============================================================================================================================================================================	
--	SELECT * FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_Additional_CertifiedOfficeService](1333595, 1, 1, 1, 55, '2021-02-07', '2021-02-07 18:27', '2021-02-07 19:22')
--
ALTER FUNCTION [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_Additional_CertifiedOfficeService](--[CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime]
	@ServiceHeaderId BIGINT,
	@ServiceTypeId INT,
	@CompanyId INT,
	@BillingToCompany INT,
	@AirportId INT,
	@DateService DATE,
	@ATA DATETIME2(0),
	@ATD DATETIME2(0)
)
RETURNS @Result TABLE(ROW INT IDENTITY, StartDate DATETIME, EndDate DATETIME, Time INT, AdditionalService BIT, AdditionalStartHour DATETIME, AdditionalEndHour DATETIME, AdditionalTime INT, AdditionalQuantity INT, AdditionalServiceName VARCHAR(150), Fraction VARCHAR(25), TimeLeftover INT)
AS
BEGIN
	DECLARE @TimeLeftover FLOAT=0

	DECLARE @ServiceDetail AS CIOReglaNegocio.ServiceDetailType--TIPO DEFINIDO
	DECLARE @ServiceDetailFiltered AS CIOReglaNegocio.ServiceDetailType--TIPO DEFINIDO

	INSERT	@ServiceDetail
	SELECT	ROW_NUMBER() OVER(ORDER BY DS.DetalleServicioId) fila,
			'DESPACHO CERTIFICADO',
			DS.FechaInicio, 
			DS.FechaFin, 
			DATEDIFF(MI, DS.FechaInicio, DS.FechaFin) Time_total, 
			DS.cantidad
	FROM	CIOServicios.DetalleServicio DS
	WHERE	DS.Activo = 1 AND
			DS.TipoActividadId = 334 AND
			DS.EncabezadoServicioId = @ServiceHeaderId --fk_id_encab_srv

	DECLARE @TransitServiceTime INT = DATEDIFF(MINUTE, @ATA, @ATD)
	DECLARE @ServiceTime INT = (SELECT SUM(TiempoTotal) FROM @ServiceDetail)

		--SPIRIT / SAI
	IF (@CompanyId=195 AND @BillingToCompany=87)
	BEGIN
		IF (@DateService >= '2023-05-09')
		BEGIN
			IF (@AirportId IN (3,4,17,9)) --MDE, CLO, CTG, AXM
			BEGIN
				INSERT @Result SELECT * FROM [CIOServicios].[UFN_CIOWeb_CalculateQuantity](@ServiceDetail, 0)
				RETURN
			END
			
			INSERT @Result SELECT * FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 30.0,NULL,NULL) 
			RETURN
		END
	END
	---- ==========================================
	---- SARPA A SARPA
	---- ==========================================
	--IF (@CompanyId = 69 AND @BillingToCompany = 69)
	--BEGIN
	--	IF (@DateService >= '2021-10-01')
	--	BEGIN
	--		RETURN --SE INCLUYE EL DESPACHO CENTRALIZADO (NO SE COBRA ADICIONAL)
	--	END
	--END

	RETURN
END