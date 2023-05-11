/****** Object:  UserDefinedFunction [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_Additional_CertifiedOfficeService]    Script Date: 11/05/2023 13:49:56 ******/
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
--	2023-05-11	Diomer Bedoya	   : Se incluye RN TALMA-SAI SPIRIT  Compañía: SPIRIT - Facturar a: SAI

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
				INSERT @Result 
				SELECT 
					CQ.StartTime
				,	CQ.FinalTime
				,	NULL
				,	CQ.IsAdditionalService
				,	NULL
				,	NULL
				,	NULL
				,	CQ.AdditionalAmount
				,	CQ.AdditionalService
				,	NULL
				,	NULL
				FROM [CIOServicios].[UFN_CIOWeb_CalculateQuantity](@ServiceDetail, 0) CQ
				RETURN
			END
			
			IF (@AirportId IN (30,32)) --BAQ, BGA
			BEGIN
				IF (@ServiceTime > 0)
				BEGIN
					INSERT	@Result
					SELECT	R.StartTime,
							R.EndTime,
							CASE WHEN MAX(R.RowNumber) OVER(PARTITION BY Service) = R.RowNumber THEN SUM(R.TotalTime) OVER(PARTITION BY Service) END Time,
							1 AdditionalService,
							R.StartTime AdditionalStartTime,
							R.EndTime AdditionalEndTime,
							CASE WHEN MAX(R.RowNumber) OVER(PARTITION BY Service) = R.RowNumber THEN SUM(R.TotalTime) OVER(PARTITION BY Service) END AdditionalTime,
							CASE WHEN MAX(R.RowNumber) OVER(PARTITION BY Service) = R.RowNumber THEN 1 END AdditionalQuanty,
							R.Service + ' FIJO X 4 HORAS' AdditionalServiceName,
							NULL FractionName,
							NULL TimeLeftover
					FROM	CIOReglaNegocio.ServiceDetailFilterByMinuteRanges(@ServiceDetail, 0, 240) R
				END

				IF (@ServiceTime > 240)
				BEGIN
					INSERT	@ServiceDetailFiltered
					SELECT	RowNumber, Service, StartTime, EndTime, TotalTime, Quantity
					FROM	CIOReglaNegocio.ServiceDetailFilterByMinuteRanges(@ServiceDetail, 120, NULL) --FRACCIONES DE 15 MIN ADICIONAL DESDE EL MINUTO 85 EN ADELANTE

					INSERT  @Result
					SELECT	StartDate
						,	EndDate
						,	Time
						,	AdditionalService
						,	AdditionalStartTime
						,	AdditionalEndTime
						,	AdditionalTime
						,	AdditionalQuanty
						,	AdditionalServiceName + ' ADICIONAL' AdditionalServiceName
						,	FractionName
						,	TimeLeftover
					FROM    [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime_V1](@ServiceDetailFiltered, 0, 60.0, '*', @ServiceHeaderId) --OJO NUEVA VERSION DE LA FUNCION
					WHERE	AdditionalService = 1
				END
				RETURN
			END
		END
	END

	INSERT @Result SELECT * FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 60.0, NULL,NULL)
	RETURN
END