/****** Object:  UserDefinedFunction [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_Additional_CentralizedOfficeService]    Script Date: 23/05/2023 8:55:32 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================================================================================================================================================	
-- Description: Function for Businees Rules "CentralizedOfficeService"
-- Change History:
--	2021-02-08	Sebastián Jaramillo: Funtion created
--	2021-11-03	Sebastián Jaramillo: Conciliación RN Despacho Centralizado AVA
--	2021-12-16	Sebastián Jaramillo: Se incluye RN Contrato Nuevo SARPA
--	2022-01-26	Sebastián Jaramillo: Se ajusta RN AVA CLO/MDE validando que los vuelos tengan ATA y ATD
--	2023-02-13	Sebastián Jaramillo: Se configura nuevo contrato de Avianca 2023 "TAKE OFF 20230201" y Regional Express se integra como un "facturar a" más de Avianca
--	2023-02-13	Sebastián Jaramillo: Inclusión RN de cobros de "FM Mobile"
--	2023-02-16	Sebastián Jaramillo: Ajustes RN inicios de fechas de cobros de "FM Mobile"
--	2023-04-20	Sebastián Jaramillo: Fusión TALMA-SAI BOGEX Incorporación RN AVA estaciones (BGA, MTR, PSO, IBE, NVA) Compañía: Avianca - Facturar a: SAI
--	2023-05-19	Diomer Bedoya	   : Se incluye RN TALMA-SAI LATAM  Compañía: LATAM - Facturar a: SAI
-- =============================================================================================================================================================================	
--	SELECT * FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_Additional_CentralizedOfficeService](1333595, 1, 1, 1, 55, '2021-02-07', '2021-02-07 18:27', '2021-02-07 19:22')
--
ALTER FUNCTION [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_Additional_CentralizedOfficeService](--[CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime]
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
			'DESPACHO CENTRALIZADO',
			DS.FechaInicio, 
			DS.FechaFin, 
			DATEDIFF(MI, DS.FechaInicio, DS.FechaFin) Time_total, 
			DS.cantidad
	FROM	CIOServicios.DetalleServicio DS
	WHERE	DS.Activo = 1 AND
			DS.TipoActividadId = 202 AND
			DS.EncabezadoServicioId = @ServiceHeaderId --fk_id_encab_srv

	DECLARE @TransitServiceTime INT = DATEDIFF(MINUTE, @ATA, @ATD)
	DECLARE @ServiceTime INT = (SELECT SUM(TiempoTotal) FROM @ServiceDetail)

	IF (SELECT SUM(TiempoTotal) FROM @ServiceDetail) = 0 AND @CompanyId <> 44 RETURN --SE TIENE ESTA LINEA PARA OPTIMIZAR EL RENDIMIENTO CON LAN NO SE PUEDE POR EL CALCULO DEL Time DENDIENTE EN EL CASO DE LAS PERNOCTAS
	
	-- ==========================================
	-- LATAM / SAI
	-- ==========================================
	IF (@CompanyId = 44 AND @BillingToCompany = 87)
	BEGIN
		RETURN --SE INCLUYE EL DESPACHO CENTRALIZADO (NO SE COBRA ADICIONAL)
	END

	-- ==========================================
	-- SARPA A SARPA
	-- ==========================================
	IF (@CompanyId = 69 AND @BillingToCompany = 69)
	BEGIN
		IF (@DateService >= '2021-10-01')
		BEGIN
			RETURN --SE INCLUYE EL DESPACHO CENTRALIZADO (NO SE COBRA ADICIONAL)
		END
	END

	-- ==========================================
	-- LAN AIRES LATAM A LAN AIRES LATAM
	-- ==========================================
	IF	(@CompanyId = 44 AND @BillingToCompany = 44)
	BEGIN
		IF (@DateService >= '2023-02-16')
		BEGIN
			--FM MOBILE
			IF (@ATA IS NOT NULL AND @ATD IS NOT NULL AND @ServiceTypeId IN (1, 23, 5)) --TRANSITO / PERNOCTA / ESCALA TECNICA
			BEGIN
				IF	(	(@AirportId = 9 AND @DateService >= '2023-03-03') --AXM
					OR	(@AirportId = 11 AND @DateService >= '2023-03-03') --BGA
					OR	(@AirportId = 25 AND @DateService >= '2023-03-16') --EYP
					OR	(@AirportId = 47 AND @DateService >= '2023-03-15') --PSO
					OR	(@AirportId = 55 AND @DateService >= '2023-02-16') --SMR
					OR	(@AirportId = 51 AND @DateService >= '2023-03-28') --RCH
					)
				BEGIN
					--OJO EN ESTE CASO NO DEPENDE QUE SE INGRESE LA ACTIVIDAD EN EL SISTEMA, ES DECIR LO COBRA SIEMPRE POR DEFAULT POR CADA SERVICIO
					INSERT  @Result
					SELECT	@ATA
						,	@ATD
						,	NULL
						,	1
						,	@ATA
						,	@ATD
						,	NULL
						,	1
						,	'FM MOBILE' AdditionalService
						,	NULL
						,	NULL
				END
			END

			RETURN
		END
	END

	-- ==========================================
	-- AVIANCA A SAI
	-- ==========================================
	IF	(@CompanyId = 1 AND @BillingToCompany = 87)
	BEGIN
		IF (@DateService >= '2023-04-19' AND @AirportId IN (11, 40, 47, 31, 43)) --BGA, MTR, PSO, IBE, NVA
		BEGIN
			RETURN --NO SALE NINGUN CONCEPTO DE COBRO EN ESTAS ESTACIONES
		END
	END

	-- ==========================================
	-- AVIANCA S.A A AVIANCA S.A
	-- AVIANCA S.A A REGIONAL EXPRESS
	-- TACA A AVIANCA S.A
	-- AEROGAL A AVIANCA S.A
	-- ==========================================
	IF	(	(@CompanyId=1 AND @BillingToCompany=1)
		OR	(@CompanyId=1 AND @BillingToCompany=193)
		OR	(@CompanyId=42 AND @BillingToCompany=1)
		OR	(@CompanyId=47 AND @BillingToCompany=1)
		)
	BEGIN
		IF (@DateService >= '2023-02-01')
		BEGIN
			--DESPACHO CENTRALIZADO
			IF (@AirportId IN (3, 4) AND @ATA IS NOT NULL AND @ATD IS NOT NULL) --AEROPUERTOS CLO / MDE
			BEGIN
				IF (@ServiceTypeId IN (1, 23, 5)) --TRANSITO / PERNOCTA / ESCALA TECNICA
				BEGIN
					--RETURN

					--OJO EN ESTE CASO NO DEPENDE QUE SE INGRESE LA ACTIVIDAD EN EL SISTEMA, ES DECIR LO COBRA SIEMPRE POR DEFAULT POR CADA SERVICIO
					INSERT  @Result
					SELECT	@ATA
						,	@ATD
						,	NULL
						,	1
						,	@ATA
						,	@ATD
						,	NULL
						,	1
						,	'DESPACHO CENTRALIZADO (SRV X VLO LLEGANDO)' AdditionalService
						,	NULL
						,	NULL
				END
			END

			IF (@AirportId NOT IN (3, 4)) --AEROPUERTOS DIFERENTES A CLO / MDE
			BEGIN
				IF (@ServiceTypeId IN (1, 23, 5)) --TRANSITO / PERNOCTA / ESCALA TECNICA
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
								R.Service + ' FIJO X 2 HORAS' AdditionalServiceName,
								NULL FractionName,
								NULL TimeLeftover
						FROM	CIOReglaNegocio.ServiceDetailFilterByMinuteRanges(@ServiceDetail, 0, 120) R
					END

					IF (@ServiceTime > 120)
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
						FROM    [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime_V1](@ServiceDetailFiltered, 0, 15.0, '*', @ServiceHeaderId) --OJO NUEVA VERSION DE LA FUNCION
						WHERE	AdditionalService = 1
					END
				END
			END

			--FM MOBILE SOLO SI NO SE MARCA NADA DE DESPACHO CENTRALIZADO
			IF (NOT EXISTS(SELECT TOP(1) 1 FROM @Result) AND @ATA IS NOT NULL AND @ATD IS NOT NULL AND @ServiceTypeId IN (1, 23, 5)) --TRANSITO / PERNOCTA / ESCALA TECNICA
			BEGIN
				IF	(	(@AirportId = 9 AND @DateService >= '2023-02-15') --AXM
					OR	(@AirportId = 26 AND @DateService >= '2023-02-15') --FLA
					OR	(@AirportId = 34 AND @DateService >= '2023-02-15') --LET
					OR	(@AirportId = 55 AND @DateService BETWEEN '2023-03-01' AND '2023-04-15') --SMR
					OR	(@AirportId = 55 AND @DateService >= '2023-05-01') --SMR
					OR	(@AirportId = 51 AND @DateService BETWEEN '2023-03-30' AND '2023-04-15') --RCH
					OR	(@AirportId = 51 AND @DateService >= '2023-06-01') --RCH
					OR	(@AirportId = 18 AND @DateService >= '2023-06-19') --CUC
					OR	(@AirportId = 45 AND @DateService >= '2023-06-21') --PEI
					OR	(@AirportId = 3 AND @DateService >= '2023-06-23') --MDE
					OR	(@AirportId = 4 AND @DateService >= '2023-06-25') --CLO
					)
				BEGIN
					--OJO EN ESTE CASO NO DEPENDE QUE SE INGRESE LA ACTIVIDAD EN EL SISTEMA, ES DECIR LO COBRA SIEMPRE POR DEFAULT POR CADA SERVICIO
					INSERT  @Result
					SELECT	@ATA
						,	@ATD
						,	NULL
						,	1
						,	@ATA
						,	@ATD
						,	NULL
						,	1
						,	'FM MOBILE' AdditionalService
						,	NULL
						,	NULL
				END
			END
	
			RETURN
		END
	END

	IF (@CompanyId=1 AND @BillingToCompany=1) --AVIANCA S.A A AVIANCA S.A
	BEGIN
		IF (@DateService BETWEEN '2020-12-01' AND '2023-01-31')
		BEGIN
			IF (@AirportId IN (3, 4) AND @ATA IS NOT NULL AND @ATD IS NOT NULL) --AEROPUERTOS CLO / MDE
			BEGIN
				--INSERT  @Result
				--SELECT	StartTime
				--	,	FinalTime
				--	,	NULL
				--	,	IsAdditionalService
				--	,	StartTime
				--	,	FinalTime
				--	,	NULL
				--	,	AdditionalAmount
				--	,	AdditionalService
				--	,	NULL
				--	,	NULL
				--FROM	[CIOServicios].[UFN_CIOWeb_CalculateQuantity](@ServiceDetail, 0)

				IF (@ServiceTypeId IN (1, 23, 5)) --TRANSITO / PERNOCTA / ESCALA TECNICA
				BEGIN
					--RETURN

					--OJO EN ESTE CASO NO DEPENDE QUE SE INGRESE LA ACTIVIDAD EN EL SISTEMA, ES DECIR LO COBRA SIEMPRE POR DEFAULT POR CADA SERVICIO
					INSERT  @Result
					SELECT	@ATA
						,	@ATD
						,	NULL
						,	1
						,	@ATA
						,	@ATD
						,	NULL
						,	1
						,	'DESPACHO CENTRALIZADO (SRV X VLO LLEGANDO)' AdditionalService
						,	NULL
						,	NULL
				END
			END

			IF (@AirportId NOT IN (3, 4)) --AEROPUERTOS DIFERENTES A CLO / MDE
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
							R.Service + ' FIJO X 2 HORAS' AdditionalServiceName,
							NULL FractionName,
							NULL TimeLeftover
					FROM	CIOReglaNegocio.ServiceDetailFilterByMinuteRanges(@ServiceDetail, 0, 120) R
				END

				IF (@ServiceTime > 120)
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
					FROM    [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime_V1](@ServiceDetailFiltered, 0, 15.0, '*', @ServiceHeaderId) --OJO NUEVA VERSION DE LA FUNCION
					WHERE	AdditionalService = 1
				END
			END

			RETURN
		END
	END

	-- ==========================================
	-- REGIONAL EXPRESS A AVIANCA S.A
	-- ==========================================
	IF (@CompanyId = 193 AND @BillingToCompany = 1)
	BEGIN
		IF EXISTS (	SELECT	TOP(1) 1 
					FROM	[CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_FullHandling] (@AirportId, @CompanyId, @BillingToCompany, @DateService) FH
					WHERE	ISNULL(FH.Aplica, 0) = 1 )
		BEGIN
			RETURN -- PARA REGIONAL EXPRESS EN EL SERVICIO DE FULLHANDLING SE INCLUYE EL DESPACHO CENTRALIZADO (NO SE COBRA ADICIONAL)
		END

		RETURN
	END
			
	--SI NO CUMPLE NINGUNA ANTERIOR OTRAS COMPAÑIAS
	INSERT @Result SELECT * FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 60.0, NULL,NULL)
	RETURN
END