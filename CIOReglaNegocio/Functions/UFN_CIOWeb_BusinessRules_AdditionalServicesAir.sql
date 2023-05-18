/****** Object:  UserDefinedFunction [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_AdditionalServicesAir]    Script Date: 18/05/2023 14:06:42 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- ============================================================================================================================================================================
-- Description: Function for Businees Rules "Services Air"
-- Change History:
--	2019-10-29	Diomer Bedoya: Funtion created
--	2020-09-14	Sebastián Jaramillo: Otro Sí Covid VIVA AIR
--	2020-10-19	Sebastián Jaramillo: Nueva negociación AVIANCA
--	2020-10-23	Sebastián Jaramillo: Modificación/Ajuste VIVA AIR
--	2020-10-25	Sebastián Jaramillo: Modificación/Ajuste VIVA AIR
--	2020-12-16	Sebastián Jaramillo: Nueva RN GCA - Gran Colombia
--	2021-03-17	Sebastián Jaramillo: Restructuración regla ACU VivaColombia y VivaPeru
--	2021-07-21	Sebastián Jaramillo: Se cambia RN de Regional Express
--	2021-08-31	Sebastián Jaramillo: Se incluye RN de VivaAerobus
--	2021-09-16	Sebastián Jaramillo: Se cambia RN AVA para LET específicamente
--	2021-11-10	Sebastián Jaramillo: Se incluye RN Atención AVA - SAI en BOG
--	2021-12-06	Sebastián Jaramillo: Nueva RN American Airlines
--	2022-01-31	Sebastián Jaramillo: Nueva RN Ultra Air
--	2022-07-28	Sebastián Jaramillo: Se ajusta RN VivaColombia para indicar explícitamente servicios internacionales
--	2022-09-28	Sebastián Jaramillo: Se adicionan RN Arajet
--	2023-02-13	Sebastián Jaramillo: Se configura nuevo contrato de Avianca 2023 "TAKE OFF 20230201" y Regional Express se integra como un "facturar a" más de Avianca
--	2023-03-30	Sebastián Jaramillo: Se configura RN LATAM RCH
--	2023-04-21	Sebastián Jaramillo: Fusión TALMA-SAI BOGEX Incorporación RN AVA estaciones (BGA, MTR, PSO, IBE, NVA) Compañía: Avianca - Facturar a: SAI
--	2023-05-09	Diomer Bedoya	   : Se incluye RN TALMA-SAI SPIRIT  Compañía: SPIRIT - Facturar a: SAI
--	2023-05-11	Diomer Bedoya	   : Se incluye RN TALMA-SAI AMERICAN AIRLINES  Compañía: AMERICAN AIRLINES - Facturar a: SAI
--	2023-05-11	Diomer Bedoya	   : Se incluye RN TALMA-SAI AEROMÉXICO  Compañía: AEROMÉXICO - Facturar a: SAI
--	2023-05-11	Diomer Bedoya	   : Se incluye RN TALMA-SAI JETAIR  Compañía: JETAIR - Facturar a: SAI
--	2023-05-15	Sebastián Jaramillo: Se ajusta RN de Avianca para las estaciones LASA para entrar a generar facturación por simultaneidad en la otra función especial.
--	2023-05-11	Diomer Bedoya	   : Se incluye RN TALMA-SAI LATAM  Compañía: LATAM - Facturar a: SAI
--	2023-05-18	Diomer Bedoya	   : Se incluye RN TALMA-SAI KLM  Compañía: KLM - Facturar a: SAI
--	2023-05-18	Diomer Bedoya	   : Se incluye RN TALMA-SAI AIR TRANSAT   Compañía: AIR TRANSAT  - Facturar a: SAI
-- ============================================================================================================================================================================
ALTER FUNCTION [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_AdditionalServicesAir](--[CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime]
	@ServiceHeaderId BIGINT,
	@ServiceTypeId INT,
	@CompanyId INT,
	@BillingToCompanyId INT,
	@AirportId INT,
	@OriginId INT,
	@DestinationId INT,	
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

	DECLARE	@ExtraText VARCHAR(50) = ''

	INSERT	@ServiceDetail
	SELECT	ROW_NUMBER() OVER(ORDER BY DS.DetalleServicioId) fila,
			'AIRE ACONDICIONADO',
			DS.FechaInicio, 
			DS.FechaFin, 
			DATEDIFF(MI, DS.FechaInicio, DS.FechaFin) Time_total, 
			DS.cantidad
	FROM	CIOServicios.DetalleServicio DS
	WHERE	DS.Activo = 1 AND
			DS.TipoActividadId = 4 AND
			DS.EncabezadoServicioId = @ServiceHeaderId --fk_id_encab_srv

	DECLARE @TransitServiceTime INT = DATEDIFF(MINUTE, @ATA, @ATD)
	DECLARE @ServiceAirTime INT = (SELECT SUM(TiempoTotal) FROM @ServiceDetail)

	IF (SELECT SUM(TiempoTotal) FROM @ServiceDetail) = 0 AND @CompanyId <> 44 RETURN --SE TIENE ESTA LINEA PARA OPTIMIZAR EL RENDIMIENTO CON LAN NO SE PUEDE POR EL CALCULO DEL Time DENDIENTE EN EL CASO DE LAS PERNOCTAS
	
	IF (@CompanyId=130 AND @BillingToCompanyId=87) --AIR TRANSAT / SAI
	BEGIN
		INSERT @Result SELECT * FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 15.0,NULL,NULL) 
		RETURN
	END

	IF (@CompanyId=59 AND @BillingToCompanyId=87) --KLM / SAI
	BEGIN
		INSERT @Result SELECT * FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 60.0,NULL,NULL) 
		RETURN
	END

	IF (@CompanyId=295 AND @BillingToCompanyId=87) --JETAIR / SAI
	BEGIN
		INSERT @Result SELECT * FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 60.0,NULL,NULL) 
		RETURN
	END

	IF (@CompanyId=58 AND @BillingToCompanyId=87) --AEROMÉXICO / SAI
	BEGIN
		INSERT @Result SELECT * FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 60.0,NULL,NULL) 
		RETURN
	END

	-- AMERICAN AIRLINES / SAI
	IF (@CompanyId=43 AND @BillingToCompanyId=87)
	BEGIN
		IF (@AirportId IN (4)) --CLO
		BEGIN
			INSERT	@Result 
			SELECT	CQ.StartTime
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
			FROM [CIOServicios].[UFN_CIOWeb_CalculateQuantity](@ServiceDetail, 1) CQ

			RETURN
		END

		IF (@AirportId IN (17,45)) --CTG, PEI
		BEGIN
			INSERT @Result SELECT * FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 60, 30.0,NULL,NULL) 
			
			RETURN
		END
	END

	IF (@CompanyId=195 AND @BillingToCompanyId=87) --SPIRIT / SAI
	BEGIN
		IF (@AirportId IN (3,4,17)) --MDE, CLO, CTG
		BEGIN
			INSERT @Result SELECT * FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 30.0,NULL,NULL) 
			RETURN
		END
		ELSE
		IF (@AirportId IN (9,10,11))-- AXM, BAQ, BGA
		BEGIN
			-- Modalidad arriendo pago mensual, no se cobra adicional. 
			RETURN
		END
	END

	IF (@CompanyId=272 AND @BillingToCompanyId=272) --ARAJET / ARAJET
	BEGIN
		IF (@DateService >= '2022-09-15')
		BEGIN
			INSERT @Result SELECT * FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 30.0,NULL,NULL)

			RETURN
		END
	END

	IF (@CompanyId=259 AND @BillingToCompanyId=259) --ULTRA AIR / ULTRA AIR
	BEGIN
		IF (@DateService >= '2022-01-20')
		BEGIN
			INSERT @Result SELECT * FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 30.0,NULL,NULL)

			RETURN
		END
	END

	IF (@CompanyId=43 AND @BillingToCompanyId=43) --AMERICAN AIRLINES / AMERICAN AIRLINES
	BEGIN
		IF (@DateService >= '2021-12-04')
		BEGIN
			INSERT @Result SELECT * FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 30.0,NULL,NULL)

			RETURN
		END
	END

	IF (@CompanyId = 255 AND @BillingToCompanyId = 255) --VIVAAEROBUS / VIVAAEROBUS                     
	BEGIN
		IF (@DateService >= '2021-08-21')
		BEGIN
			INSERT @Result SELECT * FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 30.0,NULL,NULL)
			RETURN
		END

		RETURN
	END

	IF (@CompanyId = 47 AND @BillingToCompanyId = 47 AND @DateService >= '2019-12-16') --VIVA PERU
	BEGIN
		RETURN -- SE MANEJA POR AIRES SIMULTANEOS MAURO RUGE
	END

	IF (@CompanyId = 192 AND @BillingToCompanyId = 192) --VIVA PERU
	BEGIN
		IF (@DateService >= '2021-03-01') --NUEVO OTRO SI VIVA AIR COVID
		BEGIN
			IF (@ServiceTypeId IN (2,3)) --DURANTE EL ULTIMO VUELO + LIMPIEZA TERMINAL
			BEGIN
				DELETE	@ServiceDetailFiltered
				INSERT	@ServiceDetailFiltered
				SELECT	RowNumber, Service, StartTime, EndTime, TotalTime, Quantity
				FROM	CIOReglaNegocio.ServiceDetailFilterByMinuteRanges_V2(@ServiceDetail, 0, NULL, '2,3', @ServiceHeaderId) --FRACCIONES DE 15 MIN ADICIONAL DESDE EL MINUTO 85 EN ADELANTE

				INSERT  @Result
				SELECT	StartDate
					,	EndDate
					,	Time
					,	AdditionalService
					,	AdditionalStartTime
					,	AdditionalEndTime
					,	AdditionalTime
					,	AdditionalQuanty
					,	CONCAT(AdditionalServiceName, ' (PNTA)') AdditionalServiceName
					,	FractionName
					,	TimeLeftover
				FROM    [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime_V1](@ServiceDetailFiltered, 0, 15.0, '*', @ServiceHeaderId) --OJO NUEVA VERSION DE LA FUNCION
				WHERE	AdditionalService = 1

				RETURN
			END

			IF (@ServiceTypeId = 4) --DURANTE EL PRIMER VUELO
			BEGIN
				DELETE	@ServiceDetailFiltered
				INSERT	@ServiceDetailFiltered
				SELECT	RowNumber, Service, StartTime, EndTime, TotalTime, Quantity
				FROM	CIOReglaNegocio.ServiceDetailFilterByMinuteRanges_V2(@ServiceDetail, 0, NULL, '4', @ServiceHeaderId) --SE OBTIENE TODO EL DETALLE SOLAMENTE FILTRANDO LA PORCION DE PRIMER VUELO

				SET @ServiceAirTime = (SELECT SUM(TiempoTotal) FROM @ServiceDetailFiltered)

				IF (@ServiceAirTime > 0 AND @ServiceAirTime <= 15)
				BEGIN
					INSERT		@Result
					SELECT		R.StartTime,
								R.EndTime,
								CASE WHEN MAX(R.RowNumber) OVER(PARTITION BY Service) = R.RowNumber THEN SUM(R.TotalTime) OVER(PARTITION BY Service) END Time,
								1 AdditionalService,
								R.StartTime AdditionalStartTime,
								R.EndTime AdditionalEndTime,
								CASE WHEN MAX(R.RowNumber) OVER(PARTITION BY Service) = R.RowNumber THEN SUM(R.TotalTime) OVER(PARTITION BY Service) END AdditionalTime,
								CASE WHEN MAX(R.RowNumber) OVER(PARTITION BY Service) = R.RowNumber THEN 1 END AdditionalQuanty,
								CONCAT(FD.FractionName, ' ', R.Service, ' (PVLO)') AdditionalServiceName,
								FD.FractionName,
								NULL TimeLeftover
					FROM		[CIOReglaNegocio].[ServiceDetailFilterByMinuteRanges_V2](@ServiceDetailFiltered, 0, 15, '*', NULL) R
					OUTER APPLY [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_FractionDetail](15) FD --FRACCION DE 15 MINUTOS
				END

				IF (@ServiceAirTime > 15)
				BEGIN
					INSERT		@Result
					SELECT		R.StartTime,
								R.EndTime,
								CASE WHEN MAX(R.RowNumber) OVER(PARTITION BY Service) = R.RowNumber THEN SUM(R.TotalTime) OVER(PARTITION BY Service) END Time,
								1 AdditionalService,
								R.StartTime AdditionalStartTime,
								R.EndTime AdditionalEndTime,
								CASE WHEN MAX(R.RowNumber) OVER(PARTITION BY Service) = R.RowNumber THEN SUM(R.TotalTime) OVER(PARTITION BY Service) END AdditionalTime,
								CASE WHEN MAX(R.RowNumber) OVER(PARTITION BY Service) = R.RowNumber THEN 1 END AdditionalQuanty,
								CONCAT(FD.FractionName, ' ', R.Service, ' (PVLO)') AdditionalServiceName,
								FD.FractionName,
								NULL TimeLeftover
					FROM		[CIOReglaNegocio].[ServiceDetailFilterByMinuteRanges_V2](@ServiceDetailFiltered, 0, 30, '*', NULL) R
					OUTER APPLY [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_FractionDetail](30) FD --FRACCION DE 30 MINUTOS

					IF (@ServiceAirTime > 30)
					BEGIN
						DELETE	@ServiceDetail
						INSERT	@ServiceDetail
						SELECT	RowNumber, Service, StartTime, EndTime, TotalTime, Quantity
						FROM	CIOReglaNegocio.ServiceDetailFilterByMinuteRanges_V2(@ServiceDetailFiltered, 30, NULL, '*', NULL) --FRACCIONES DE 15 MIN ADICIONAL DESDE EL MINUTO 31 EN ADELANTE

						INSERT  @Result
						SELECT	StartDate
							,	EndDate
							,	Time
							,	AdditionalService
							,	AdditionalStartTime
							,	AdditionalEndTime
							,	AdditionalTime
							,	AdditionalQuanty
							,	CONCAT(AdditionalServiceName, ' (PVLO)') AdditionalServiceName
							,	FractionName
							,	TimeLeftover
						FROM    [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime_V1](@ServiceDetail, 0, 15.0, '*', @ServiceHeaderId) --OJO NUEVA VERSION DE LA FUNCION
						WHERE	AdditionalService = 1
					END
				END

				RETURN
			END

			IF (@ServiceTypeId NOT IN (2, 3, 4)) -- PARA TRANSITO Y OTROS
			BEGIN
				IF (@ServiceAirTime > 0 AND @ServiceAirTime <= 15)
				BEGIN
					INSERT		@Result
					SELECT		R.StartTime,
								R.EndTime,
								CASE WHEN MAX(R.RowNumber) OVER(PARTITION BY Service) = R.RowNumber THEN SUM(R.TotalTime) OVER(PARTITION BY Service) END Time,
								1 AdditionalService,
								R.StartTime AdditionalStartTime,
								R.EndTime AdditionalEndTime,
								CASE WHEN MAX(R.RowNumber) OVER(PARTITION BY Service) = R.RowNumber THEN SUM(R.TotalTime) OVER(PARTITION BY Service) END AdditionalTime,
								CASE WHEN MAX(R.RowNumber) OVER(PARTITION BY Service) = R.RowNumber THEN 1 END AdditionalQuanty,
								CONCAT(FD.FractionName, ' ', R.Service, ' (TTO)') AdditionalServiceName,
								FD.FractionName,
								NULL TimeLeftover
					FROM		[CIOReglaNegocio].[ServiceDetailFilterByMinuteRanges_V2](@ServiceDetail, 0, 15, '*', NULL) R
					OUTER APPLY [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_FractionDetail](15) FD --FRACCION DE 15 MINUTOS
				END

				IF (@ServiceAirTime > 15 AND @ServiceAirTime <= 30)
				BEGIN
					INSERT		@Result
					SELECT		R.StartTime,
								R.EndTime,
								CASE WHEN MAX(R.RowNumber) OVER(PARTITION BY Service) = R.RowNumber THEN SUM(R.TotalTime) OVER(PARTITION BY Service) END Time,
								1 AdditionalService,
								R.StartTime AdditionalStartTime,
								R.EndTime AdditionalEndTime,
								CASE WHEN MAX(R.RowNumber) OVER(PARTITION BY Service) = R.RowNumber THEN SUM(R.TotalTime) OVER(PARTITION BY Service) END AdditionalTime,
								CASE WHEN MAX(R.RowNumber) OVER(PARTITION BY Service) = R.RowNumber THEN 1 END AdditionalQuanty,
								CONCAT(FD.FractionName, ' ', R.Service, ' (TTO)') AdditionalServiceName,
								FD.FractionName,
								NULL TimeLeftover
					FROM		[CIOReglaNegocio].[ServiceDetailFilterByMinuteRanges_V2](@ServiceDetail, 0, 30, '*', NULL) R
					OUTER APPLY [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_FractionDetail](30) FD --FRACCION DE 30 MINUTOS
				END

				IF (@ServiceAirTime > 30)
				BEGIN
					INSERT		@Result
					SELECT		R.StartTime,
								R.EndTime,
								CASE WHEN MAX(R.RowNumber) OVER(PARTITION BY Service) = R.RowNumber THEN SUM(R.TotalTime) OVER(PARTITION BY Service) END Time,
								1 AdditionalService,
								R.StartTime AdditionalStartTime,
								R.EndTime AdditionalEndTime,
								CASE WHEN MAX(R.RowNumber) OVER(PARTITION BY Service) = R.RowNumber THEN SUM(R.TotalTime) OVER(PARTITION BY Service) END AdditionalTime,
								CASE WHEN MAX(R.RowNumber) OVER(PARTITION BY Service) = R.RowNumber THEN 1 END AdditionalQuanty,
								CONCAT(FD.FractionName, ' ', R.Service, ' (TTO)') AdditionalServiceName,
								FD.FractionName,
								NULL TimeLeftover
					FROM		[CIOReglaNegocio].[ServiceDetailFilterByMinuteRanges_V2](@ServiceDetail, 0, 45, '*', NULL) R
					OUTER APPLY [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_FractionDetail](45) FD --FRACCION DE 45 MINUTOS

					IF (@ServiceAirTime > 45)
					BEGIN
						DELETE	@ServiceDetailFiltered
						INSERT	@ServiceDetailFiltered
						SELECT	RowNumber, Service, StartTime, EndTime, TotalTime, Quantity
						FROM	CIOReglaNegocio.ServiceDetailFilterByMinuteRanges_V2(@ServiceDetail, 45, NULL, '*', NULL) --FRACCIONES DE 15 MIN ADICIONAL DESDE EL MINUTO 46 EN ADELANTE

						INSERT  @Result
						SELECT	StartDate
							,	EndDate
							,	Time
							,	AdditionalService
							,	AdditionalStartTime
							,	AdditionalEndTime
							,	AdditionalTime
							,	AdditionalQuanty
							,	CONCAT(AdditionalServiceName, ' (TTO)') AdditionalServiceName
							,	FractionName
							,	TimeLeftover
						FROM    [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime_V1](@ServiceDetailFiltered, 0, 15.0, '*', @ServiceHeaderId) --OJO NUEVA VERSION DE LA FUNCION
						WHERE	AdditionalService = 1
					END
				END

				RETURN
			END

		END

		IF (@DateService BETWEEN '2016-06-01' AND '2020-08-31')
		BEGIN
			RETURN -- DURANTE ESTE RANGO DE FECHAS SE MANEJO UN REPORTE DE BOLSAS A NIVEL NACIONAL (SE TRATO POR OTRO LADO)
		END

		RETURN
	END

	IF (@CompanyId = 60 AND @BillingToCompanyId = 90) --VIVA COLOMBIA                           
	BEGIN
		IF (@DateService >= '2021-03-01') --NUEVO OTRO SI VIVA AIR COVID
		BEGIN
			IF (CIOServicios.UFN_CIO_InternationalFlight(@AirportId, @DestinationId) = 1)
			BEGIN
				SET @ExtraText = ' INTERNACIONAL'
			END

			IF (@ServiceTypeId IN (2,3)) --DURANTE EL ULTIMO VUELO + LIMPIEZA TERMINAL
			BEGIN
				DELETE	@ServiceDetailFiltered
				INSERT	@ServiceDetailFiltered
				SELECT	RowNumber, Service, StartTime, EndTime, TotalTime, Quantity
				FROM	CIOReglaNegocio.ServiceDetailFilterByMinuteRanges_V2(@ServiceDetail, 0, NULL, '2,3', @ServiceHeaderId) --FRACCIONES DE 15 MIN ADICIONAL DESDE EL MINUTO 85 EN ADELANTE

				INSERT  @Result
				SELECT	StartDate
					,	EndDate
					,	Time
					,	AdditionalService
					,	AdditionalStartTime
					,	AdditionalEndTime
					,	AdditionalTime
					,	AdditionalQuanty
					,	CONCAT(AdditionalServiceName, @ExtraText, ' (PNTA)') AdditionalServiceName
					,	FractionName
					,	TimeLeftover
				FROM    [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime_V1](@ServiceDetailFiltered, 0, 15.0, '*', @ServiceHeaderId) --OJO NUEVA VERSION DE LA FUNCION
				WHERE	AdditionalService = 1

				RETURN
			END

			IF (@ServiceTypeId = 4) --DURANTE EL PRIMER VUELO
			BEGIN
				DELETE	@ServiceDetailFiltered
				INSERT	@ServiceDetailFiltered
				SELECT	RowNumber, Service, StartTime, EndTime, TotalTime, Quantity
				FROM	CIOReglaNegocio.ServiceDetailFilterByMinuteRanges_V2(@ServiceDetail, 0, NULL, '4', @ServiceHeaderId) --SE OBTIENE TODO EL DETALLE SOLAMENTE FILTRANDO LA PORCION DE PRIMER VUELO

				SET @ServiceAirTime = (SELECT SUM(TiempoTotal) FROM @ServiceDetailFiltered)

				IF (@ServiceAirTime > 0 AND @ServiceAirTime <= 15)
				BEGIN
					INSERT		@Result
					SELECT		R.StartTime,
								R.EndTime,
								CASE WHEN MAX(R.RowNumber) OVER(PARTITION BY Service) = R.RowNumber THEN SUM(R.TotalTime) OVER(PARTITION BY Service) END Time,
								1 AdditionalService,
								R.StartTime AdditionalStartTime,
								R.EndTime AdditionalEndTime,
								CASE WHEN MAX(R.RowNumber) OVER(PARTITION BY Service) = R.RowNumber THEN SUM(R.TotalTime) OVER(PARTITION BY Service) END AdditionalTime,
								CASE WHEN MAX(R.RowNumber) OVER(PARTITION BY Service) = R.RowNumber THEN 1 END AdditionalQuanty,
								CONCAT(FD.FractionName, ' ', R.Service, @ExtraText, ' (PVLO)') AdditionalServiceName,
								FD.FractionName,
								NULL TimeLeftover
					FROM		[CIOReglaNegocio].[ServiceDetailFilterByMinuteRanges_V2](@ServiceDetailFiltered, 0, 15, '*', NULL) R
					OUTER APPLY [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_FractionDetail](15) FD --FRACCION DE 15 MINUTOS
				END

				IF (@ServiceAirTime > 15)
				BEGIN
					INSERT		@Result
					SELECT		R.StartTime,
								R.EndTime,
								CASE WHEN MAX(R.RowNumber) OVER(PARTITION BY Service) = R.RowNumber THEN SUM(R.TotalTime) OVER(PARTITION BY Service) END Time,
								1 AdditionalService,
								R.StartTime AdditionalStartTime,
								R.EndTime AdditionalEndTime,
								CASE WHEN MAX(R.RowNumber) OVER(PARTITION BY Service) = R.RowNumber THEN SUM(R.TotalTime) OVER(PARTITION BY Service) END AdditionalTime,
								CASE WHEN MAX(R.RowNumber) OVER(PARTITION BY Service) = R.RowNumber THEN 1 END AdditionalQuanty,
								CONCAT(FD.FractionName, ' ', R.Service, @ExtraText, ' (PVLO)') AdditionalServiceName,
								FD.FractionName,
								NULL TimeLeftover
					FROM		[CIOReglaNegocio].[ServiceDetailFilterByMinuteRanges_V2](@ServiceDetailFiltered, 0, 30, '*', NULL) R
					OUTER APPLY [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_FractionDetail](30) FD --FRACCION DE 30 MINUTOS

					IF (@ServiceAirTime > 30)
					BEGIN
						DELETE	@ServiceDetail
						INSERT	@ServiceDetail
						SELECT	RowNumber, Service, StartTime, EndTime, TotalTime, Quantity
						FROM	CIOReglaNegocio.ServiceDetailFilterByMinuteRanges_V2(@ServiceDetailFiltered, 30, NULL, '*', NULL) --FRACCIONES DE 15 MIN ADICIONAL DESDE EL MINUTO 31 EN ADELANTE

						INSERT  @Result
						SELECT	StartDate
							,	EndDate
							,	Time
							,	AdditionalService
							,	AdditionalStartTime
							,	AdditionalEndTime
							,	AdditionalTime
							,	AdditionalQuanty
							,	CONCAT(AdditionalServiceName, @ExtraText, ' (PVLO)') AdditionalServiceName
							,	FractionName
							,	TimeLeftover
						FROM    [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime_V1](@ServiceDetail, 0, 15.0, '*', @ServiceHeaderId) --OJO NUEVA VERSION DE LA FUNCION
						WHERE	AdditionalService = 1
					END
				END

				RETURN
			END

			IF (@ServiceTypeId NOT IN (2, 3, 4)) -- PARA TRANSITO Y OTROS
			BEGIN
				IF (@ServiceAirTime > 0 AND @ServiceAirTime <= 15)
				BEGIN
					INSERT		@Result
					SELECT		R.StartTime,
								R.EndTime,
								CASE WHEN MAX(R.RowNumber) OVER(PARTITION BY Service) = R.RowNumber THEN SUM(R.TotalTime) OVER(PARTITION BY Service) END Time,
								1 AdditionalService,
								R.StartTime AdditionalStartTime,
								R.EndTime AdditionalEndTime,
								CASE WHEN MAX(R.RowNumber) OVER(PARTITION BY Service) = R.RowNumber THEN SUM(R.TotalTime) OVER(PARTITION BY Service) END AdditionalTime,
								CASE WHEN MAX(R.RowNumber) OVER(PARTITION BY Service) = R.RowNumber THEN 1 END AdditionalQuanty,
								CONCAT(FD.FractionName, ' ', R.Service, @ExtraText, ' (TTO)') AdditionalServiceName,
								FD.FractionName,
								NULL TimeLeftover
					FROM		[CIOReglaNegocio].[ServiceDetailFilterByMinuteRanges_V2](@ServiceDetail, 0, 15, '*', NULL) R
					OUTER APPLY [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_FractionDetail](15) FD --FRACCION DE 15 MINUTOS
				END

				IF (@ServiceAirTime > 15 AND @ServiceAirTime <= 30)
				BEGIN
					INSERT		@Result
					SELECT		R.StartTime,
								R.EndTime,
								CASE WHEN MAX(R.RowNumber) OVER(PARTITION BY Service) = R.RowNumber THEN SUM(R.TotalTime) OVER(PARTITION BY Service) END Time,
								1 AdditionalService,
								R.StartTime AdditionalStartTime,
								R.EndTime AdditionalEndTime,
								CASE WHEN MAX(R.RowNumber) OVER(PARTITION BY Service) = R.RowNumber THEN SUM(R.TotalTime) OVER(PARTITION BY Service) END AdditionalTime,
								CASE WHEN MAX(R.RowNumber) OVER(PARTITION BY Service) = R.RowNumber THEN 1 END AdditionalQuanty,
								CONCAT(FD.FractionName, ' ', R.Service, @ExtraText, ' (TTO)') AdditionalServiceName,
								FD.FractionName,
								NULL TimeLeftover
					FROM		[CIOReglaNegocio].[ServiceDetailFilterByMinuteRanges_V2](@ServiceDetail, 0, 30, '*', NULL) R
					OUTER APPLY [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_FractionDetail](30) FD --FRACCION DE 30 MINUTOS
				END

				IF (@ServiceAirTime > 30)
				BEGIN
					INSERT		@Result
					SELECT		R.StartTime,
								R.EndTime,
								CASE WHEN MAX(R.RowNumber) OVER(PARTITION BY Service) = R.RowNumber THEN SUM(R.TotalTime) OVER(PARTITION BY Service) END Time,
								1 AdditionalService,
								R.StartTime AdditionalStartTime,
								R.EndTime AdditionalEndTime,
								CASE WHEN MAX(R.RowNumber) OVER(PARTITION BY Service) = R.RowNumber THEN SUM(R.TotalTime) OVER(PARTITION BY Service) END AdditionalTime,
								CASE WHEN MAX(R.RowNumber) OVER(PARTITION BY Service) = R.RowNumber THEN 1 END AdditionalQuanty,
								CONCAT(FD.FractionName, ' ', R.Service, @ExtraText, ' (TTO)') AdditionalServiceName,
								FD.FractionName,
								NULL TimeLeftover
					FROM		[CIOReglaNegocio].[ServiceDetailFilterByMinuteRanges_V2](@ServiceDetail, 0, 45, '*', NULL) R
					OUTER APPLY [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_FractionDetail](45) FD --FRACCION DE 45 MINUTOS

					IF (@ServiceAirTime > 45)
					BEGIN
						DELETE	@ServiceDetailFiltered
						INSERT	@ServiceDetailFiltered
						SELECT	RowNumber, Service, StartTime, EndTime, TotalTime, Quantity
						FROM	CIOReglaNegocio.ServiceDetailFilterByMinuteRanges_V2(@ServiceDetail, 45, NULL, '*', NULL) --FRACCIONES DE 15 MIN ADICIONAL DESDE EL MINUTO 46 EN ADELANTE

						INSERT  @Result
						SELECT	StartDate
							,	EndDate
							,	Time
							,	AdditionalService
							,	AdditionalStartTime
							,	AdditionalEndTime
							,	AdditionalTime
							,	AdditionalQuanty
							,	CONCAT(AdditionalServiceName, @ExtraText, ' (TTO)') AdditionalServiceName
							,	FractionName
							,	TimeLeftover
						FROM    [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime_V1](@ServiceDetailFiltered, 0, 15.0, '*', @ServiceHeaderId) --OJO NUEVA VERSION DE LA FUNCION
						WHERE	AdditionalService = 1
					END
				END

				RETURN
			END

		END

		IF (@DateService BETWEEN '2020-09-01' AND '2021-02-28') --OTRO SI VIVA AIR COVID
		BEGIN
			IF (@TransitServiceTime <= 70)
			BEGIN
				IF (@ServiceAirTime > 0)
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
							R.Service + ' FIJO X 55 MINUTOS (TTO CORTO)' AdditionalServiceName,
							NULL FractionName,
							NULL TimeLeftover
					FROM	CIOReglaNegocio.ServiceDetailFilterByMinuteRanges(@ServiceDetail, 0, 55) R
				END

				IF (@ServiceAirTime > 55)
				BEGIN
					INSERT	@ServiceDetailFiltered
					SELECT	RowNumber, Service, StartTime, EndTime, TotalTime, Quantity
					FROM	CIOReglaNegocio.ServiceDetailFilterByMinuteRanges(@ServiceDetail, 55, NULL)

					INSERT  @Result
					SELECT	StartDate
						,	EndDate
						,	Time
						,	AdditionalService
						,	AdditionalStartTime
						,	AdditionalEndTime
						,	AdditionalTime
						,	AdditionalQuanty
						,	AdditionalServiceName + ' (TTO CORTO)' AdditionalServiceName
						,	FractionName
						,	TimeLeftover
					FROM    [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime_V1](@ServiceDetailFiltered, 0, 15.0, '*', @ServiceHeaderId) --OJO NUEVA VERSION DE LA FUNCION
					WHERE	AdditionalService = 1
				END

				RETURN
			END
			ELSE
			BEGIN
				IF (@ServiceAirTime > 0)
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
							R.Service + ' FIJO X 55 MINUTOS (TTO LARGO)' AdditionalServiceName,
							NULL FractionName,
							NULL TimeLeftover
					FROM	CIOReglaNegocio.ServiceDetailFilterByMinuteRanges(@ServiceDetail, 0, 55) R --55 MINUTOS DESDE EL MINUTO 0
				END

				IF (@ServiceAirTime > 55)
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
							R.Service + ' FIJO X 30 MINUTOS (TTO LARGO)' AdditionalServiceName,
							NULL FractionName,
							NULL TimeLeftover
					FROM	CIOReglaNegocio.ServiceDetailFilterByMinuteRanges(@ServiceDetail, 55, 85) R --30 MINUTOS DESPUES DE LOS PRIMEROS 55 MINUTOS
				END

				IF (@ServiceAirTime > 85)
				BEGIN
					INSERT	@ServiceDetailFiltered
					SELECT	RowNumber, Service, StartTime, EndTime, TotalTime, Quantity
					FROM	CIOReglaNegocio.ServiceDetailFilterByMinuteRanges(@ServiceDetail, 85, NULL) --FRACCIONES DE 15 MIN ADICIONAL DESDE EL MINUTO 85 EN ADELANTE

					INSERT  @Result
					SELECT	StartDate
						,	EndDate
						,	Time
						,	AdditionalService
						,	AdditionalStartTime
						,	AdditionalEndTime
						,	AdditionalTime
						,	AdditionalQuanty
						,	AdditionalServiceName + ' (TTO LARGO)' AdditionalServiceName
						,	FractionName
						,	TimeLeftover
					FROM    [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime_V1](@ServiceDetailFiltered, 0, 15.0, '*', @ServiceHeaderId) --OJO NUEVA VERSION DE LA FUNCION
					WHERE	AdditionalService = 1
				END

				RETURN
			END
		END

		IF (@DateService BETWEEN '2016-06-01' AND '2020-08-31')
		BEGIN
			RETURN -- DURANTE ESTE RANGO DE FECHAS SE MANEJO UN REPORTE DE BOLSAS A NIVEL NACIONAL (SE TRATO POR OTRO LADO)
		END

		--REGLAS MUCHO MAS ANTIGUAS
		IF (@AirportId = 25) --EYP
		BEGIN
			INSERT @Result SELECT * FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 30.0,NULL,NULL)
			RETURN
		END

		IF (@AirportId = 34) --LET
		BEGIN
			INSERT @Result SELECT * FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 25.0,NULL,NULL)
			RETURN
		END

		IF (@AirportId = 59) --VUP
		BEGIN
			INSERT @Result SELECT * FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 25.0,NULL,NULL)
			RETURN
		END

		RETURN
	END

	IF (@CompanyId = 228 AND @BillingToCompanyId = 228) --GRAN COLOMBIA DE AVIACION (GCA)
	BEGIN
		IF (@DateService >= '2019-06-30') 
		BEGIN
			IF (@AirportId IN (18, 51)) --CUC, RCH
			BEGIN
				IF (@ServiceAirTime > 0)
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
							R.Service + ' FIJO X 60 MINUTOS' AdditionalServiceName,
							NULL FractionName,
							NULL TimeLeftover
					FROM	CIOReglaNegocio.ServiceDetailFilterByMinuteRanges(@ServiceDetail, 0, 60) R
				END

				IF (@ServiceAirTime > 60)
				BEGIN
					INSERT	@ServiceDetailFiltered
					SELECT	RowNumber, Service, StartTime, EndTime, TotalTime, Quantity
					FROM	CIOReglaNegocio.ServiceDetailFilterByMinuteRanges(@ServiceDetail, 60, NULL)

					INSERT  @Result
					SELECT	StartDate
						,	EndDate
						,	Time
						,	AdditionalService
						,	AdditionalStartTime
						,	AdditionalEndTime
						,	AdditionalTime
						,	AdditionalQuanty
						,	AdditionalServiceName AdditionalServiceName
						,	FractionName
						,	TimeLeftover
					FROM    [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime_V1](@ServiceDetailFiltered, 0, 30.0, '*', @ServiceHeaderId) --OJO NUEVA VERSION DE LA FUNCION
					WHERE	AdditionalService = 1
				END

				RETURN
			END
			BEGIN
				INSERT @Result SELECT * FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 30.0,NULL,NULL)
			END

			RETURN
		END
		BEGIN
			INSERT @Result SELECT * FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 30.0,NULL,NULL)
		END

		RETURN
	END

	IF(@CompanyId = 72 AND @BillingToCompanyId = 56) --WINGO                              
	BEGIN
		IF (@DateService <= '2019-06-30') INSERT @Result SELECT * FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 30.0,NULL,NULL)
		IF (@DateService >= '2019-07-01') INSERT @Result SELECT * FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 15.0,NULL,NULL) --ADOPTA EL MISMO MODELO QUE COPA

		RETURN
	END

	IF(@CompanyId = 81 AND @BillingToCompanyId = 81) --JET SMART                              
	BEGIN
		INSERT @Result SELECT * FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 30.0,NULL,NULL)
		RETURN
	END

	IF(@CompanyId IN (9, 56)) --COPA                              
	BEGIN
		IF (@DateService <= '2015-05-31') INSERT @Result SELECT * FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 5, 30.0,NULL,NULL)
		IF (@DateService BETWEEN '2015-06-01' AND '2019-07-15') INSERT @Result SELECT * FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 2, 15.0,NULL,NULL)
		IF (@DateService >= '2019-07-16') INSERT @Result SELECT * FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 15.0,NULL,NULL)

		RETURN
	END
		
	IF (@CompanyId = 44 /*OR @CompanyId = 7 en el at esta inactivo*/) --LATAM LAN/AIRES                           
	BEGIN
		IF (@DateService >= '2023-03-27' AND @AirportId = 51) --RCH
		BEGIN
			INSERT @Result SELECT * FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 30.0,NULL,NULL)
			RETURN
		END

		IF (@AirportId IN (40, 59)) --MTR Y VUP
		BEGIN
			INSERT @Result SELECT * FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 40.0,NULL,NULL)
			RETURN
		END
		
		IF (@AirportId = 5 AND @ServiceTypeId = 1) --ADZ --Transito TODO
		BEGIN
			INSERT @Result SELECT * FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 60, 30.0,NULL,NULL) --TIENEN 1 HORA DE AIRE EN ADZ FRAC 30
			RETURN
		END

		IF (@AirportId = 17) --CTG
		BEGIN
			IF (@ServiceTypeId = 1) --TTO
			BEGIN
				INSERT @Result SELECT * FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 35, 40.0,NULL,NULL) --TIENEN 35 MIN DE AIRE EN CTG FRAC 40
			END

			IF (@ServiceTypeId IN (2,3)) --PNTA SI ES 2 O 3
			BEGIN
				INSERT @Result SELECT * FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 35, 40.0,2,@ServiceHeaderId)
			END

			IF (@ServiceTypeId = 4) --PVLO
			BEGIN
				SELECT	@TimeLeftover = MIN(TimeLeftover)
				FROM	[CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_AdditionalServicesAir](@ServiceHeaderId,
														2,
														@CompanyId,
														@BillingToCompanyId,
														@AirportId,
														@OriginId,
														@DestinationId,
														@DateService,
														@ATA,
														@ATD)
				
				SET @TimeLeftover = ISNULL(@TimeLeftover, 35) --SI NO HAY PERNOCTA
					
				--INSERT @Result SELECT * FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, @TimeLeftover, 40.0,NULL,NULL)
				INSERT @Result SELECT * FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, @TimeLeftover, 40.0,4,@ServiceHeaderId)
			END

			IF (@ServiceTypeId NOT IN (1, 2, 3,4))
			BEGIN
				INSERT @Result SELECT * FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 40.0,NULL,NULL)
			END

			RETURN
		END
			
		IF (@DateService >= '2014-08-01')
		BEGIN
			INSERT @Result SELECT * FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 5, 30.0,NULL,NULL)
			RETURN
		END
	END

	IF (@CompanyId = 1 AND @BillingToCompanyId = 87) --AVIANCA A SAI
	BEGIN
		IF (@DateService >= '2023-04-19' AND @AirportId IN (11, 40)) --BGA, MTR
		BEGIN
			RETURN --OJO! Estas estaciones manejan un cobro especial por simultaneidad y se trata en la otra función --> CIOReglaNegocio.UFN_CIOWeb_BusinessRules_AdditionalServicesAirWithSimultaneousnessLevel
		END

		IF (@DateService >= '2023-04-19' AND @AirportId IN (47, 31, 43)) --PSO, IBE, NVA
		BEGIN
			INSERT @Result SELECT * FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 30.0,NULL,NULL)
			RETURN
		END

		IF (@DateService >= '2021-10-27' AND @AirportId = 12) --BOG
		BEGIN
			INSERT @Result SELECT * FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 30.0,NULL,NULL)
			RETURN
		END
	END

	--REGIONAL EXPRESS AMERICAS SAS / AVIANCA S.A (QUEDA OBSOLETA YA NO SE USA MAS COMO COMPAÑIA SE INTEGRA COMO FACTURAR A DE AVIANCA VER MAS ABAJO!!!)
	IF (@CompanyId=193 AND @BillingToCompanyId=1 AND @DateService >= '2021-01-01')
	BEGIN
		INSERT @Result SELECT * FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 30.0,NULL,NULL)

		RETURN
	END

	IF (@DateService >= '2023-04-01') --MODELO DE AVIANCA NUEVO CONTRATO TAKE OFF 20230201 (COBRO POR SIMULTANEIDAD A EXCEPCION DE LET)
	BEGIN
		IF	(	(@CompanyId=1 AND @BillingToCompanyId=1) --AVIANCA S.A / AVIANCA S.A
			OR	(@CompanyId=1 AND @BillingToCompanyId=193) --AVIANCA S.A / REGIONAL EXPRESS
			OR	(@CompanyId=42 AND @BillingToCompanyId=1) --TACA / AVIANCA S.A
			OR	(@CompanyId=47 AND @BillingToCompanyId=1) --AEROGAL / AVIANCA S.A
			--OR	(@CompanyId=58 AND @BillingToCompanyId=1) --AEROMÉXICO / AVIANCA S.A
			--OR	(@CompanyId=43 AND @BillingToCompanyId=1) --AMERICAN AIRLINES / AVIANCA S.A
			--OR	(@CompanyId=63 AND @BillingToCompanyId=1) --IBERIA / AVIANCA S.A
			--OR	(@CompanyId=55 AND @BillingToCompanyId=1) --JETBLUE / AVIANCA S.A
			--OR	(@CompanyId=38 AND @BillingToCompanyId=1) --TAME / AVIANCA S.A
			)
		BEGIN
			IF (@AirportId = 34) --LET
			BEGIN
				INSERT @Result SELECT * FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 30.0, NULL,NULL) --EN LET SE COBRA DESDE EL PRIMER MINUTO CORREO "20210914 - CAMBIO REGLA DE NEGOCIO AIRE ACONDICIONADO LETICIA AVIANCA"
				RETURN
			END

			RETURN --OJO! cobro especial por simultaneidad que se trata en la otra función --> CIOReglaNegocio.UFN_CIOWeb_BusinessRules_AdditionalServicesAirWithSimultaneousnessLevel
		END
	END

	IF (@DateService BETWEEN '2023-02-01' AND '2023-03-31') --MODELO DE AVIANCA NUEVO CONTRATO TAKE OFF 20230201
	BEGIN
		IF	(	(@CompanyId=1 AND @BillingToCompanyId=1) --AVIANCA S.A / AVIANCA S.A
			OR	(@CompanyId=1 AND @BillingToCompanyId=193) --AVIANCA S.A / REGIONAL EXPRESS
			OR	(@CompanyId=42 AND @BillingToCompanyId=1) --TACA / AVIANCA S.A
			OR	(@CompanyId=47 AND @BillingToCompanyId=1) --AEROGAL / AVIANCA S.A
			--OR	(@CompanyId=58 AND @BillingToCompanyId=1) --AEROMÉXICO / AVIANCA S.A
			--OR	(@CompanyId=43 AND @BillingToCompanyId=1) --AMERICAN AIRLINES / AVIANCA S.A
			--OR	(@CompanyId=63 AND @BillingToCompanyId=1) --IBERIA / AVIANCA S.A
			--OR	(@CompanyId=55 AND @BillingToCompanyId=1) --JETBLUE / AVIANCA S.A
			--OR	(@CompanyId=38 AND @BillingToCompanyId=1) --TAME / AVIANCA S.A
			)
		BEGIN
			IF (@ServiceTypeId = 1) --TRANSITOS
			BEGIN
				IF (@DateService >= '2021-09-01' AND @AirportId = 34) --LET
				BEGIN
					INSERT @Result SELECT * FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 30.0, NULL,NULL) --EN LET SE COBRA DESDE EL PRIMER MINUTO CORREO "20210914 - CAMBIO REGLA DE NEGOCIO AIRE ACONDICIONADO LETICIA AVIANCA"
					RETURN
				END

				INSERT @Result SELECT * FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 60, 30.0, NULL,NULL) --60 MINUTOS DESPUES DEL "ARRIENDO"
				RETURN
			END

			ELSE IF (@ServiceTypeId IN (2,3)) --PNTA SI ES 2 O 3
			BEGIN
				INSERT @Result SELECT * FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 60, 30.0, 2, @ServiceHeaderId) --60 MINUTOS DESPUES DEL "ARRIENDO"
			END

			ELSE IF (@ServiceTypeId = 4) --PVLO
			BEGIN
				SELECT	@TimeLeftover = MIN(TimeLeftover)
				FROM	[CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_AdditionalServicesAir](@ServiceHeaderId,
														2,
														@CompanyId,
														@BillingToCompanyId,
														@AirportId,
														@OriginId,
														@DestinationId,
														@DateService,
														@ATA,
														@ATD)
				
				SET @TimeLeftover = ISNULL(@TimeLeftover, 60) --SI NO HAY PERNOCTA
					
				--INSERT @Result SELECT * FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, @TimeLeftover, 30.0, NULL,NULL)
				INSERT @Result SELECT * FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, @TimeLeftover, 30.0,4,@ServiceHeaderId)
			END

			ELSE
			BEGIN --LOS DEMAS TIPOS DE SERVICIO
				INSERT @Result SELECT * FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 30.0,NULL,NULL)
			END

			RETURN
		END
	END

	IF (@DateService BETWEEN '2020-10-01' AND '2023-01-31') --OTRO SI NUEVA NEGOCIACION DESPUES 1 OLA COVID CON AVIANCA
	BEGIN
		IF	(	(@CompanyId=1 AND @BillingToCompanyId=1) --AVIANCA S.A / AVIANCA S.A
			OR	(@CompanyId=58 AND @BillingToCompanyId=1) --AEROMÉXICO / AVIANCA S.A
			OR	(@CompanyId=43 AND @BillingToCompanyId=1) --AMERICAN AIRLINES / AVIANCA S.A
			OR	(@CompanyId=63 AND @BillingToCompanyId=1) --IBERIA / AVIANCA S.A
			OR	(@CompanyId=55 AND @BillingToCompanyId=1) --JETBLUE / AVIANCA S.A
			OR	(@CompanyId=193 AND @BillingToCompanyId=1 AND @DateService <= '2020-12-31') --REGIONAL EXPRESS AMERICAS SAS / AVIANCA S.A (POR CORREO DE CLAUDIA MORALES "Cambios Regional Express y socialización JAT CUC" se retira de este contrato)
			OR	(@CompanyId=38 AND @BillingToCompanyId=1) --TAME / AVIANCA S.A
			)
		BEGIN
			IF (@ServiceTypeId = 1) --TRANSITOS
			BEGIN
				IF (@DateService >= '2021-09-01' AND @AirportId = 34) --LET
				BEGIN
					INSERT @Result SELECT * FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 30.0, NULL,NULL) --EN LET SE COBRA DESDE EL PRIMER MINUTO CORREO "20210914 - CAMBIO REGLA DE NEGOCIO AIRE ACONDICIONADO LETICIA AVIANCA"
					RETURN
				END

				INSERT @Result SELECT * FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 60, 30.0, NULL,NULL) --60 MINUTOS DESPUES DEL "ARRIENDO"
				RETURN
			END

			ELSE IF (@ServiceTypeId IN (2,3)) --PNTA SI ES 2 O 3
			BEGIN
				INSERT @Result SELECT * FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 60, 30.0, 2, @ServiceHeaderId) --60 MINUTOS DESPUES DEL "ARRIENDO"
			END

			ELSE IF (@ServiceTypeId = 4) --PVLO
			BEGIN
				SELECT	@TimeLeftover = MIN(TimeLeftover)
				FROM	[CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_AdditionalServicesAir](@ServiceHeaderId,
														2,
														@CompanyId,
														@BillingToCompanyId,
														@AirportId,
														@OriginId,
														@DestinationId,
														@DateService,
														@ATA,
														@ATD)
				
				SET @TimeLeftover = ISNULL(@TimeLeftover, 60) --SI NO HAY PERNOCTA
					
				--INSERT @Result SELECT * FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, @TimeLeftover, 30.0, NULL,NULL)
				INSERT @Result SELECT * FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, @TimeLeftover, 30.0,4,@ServiceHeaderId)
			END

			ELSE
			BEGIN --LOS DEMAS TIPOS DE SERVICIO
				INSERT @Result SELECT * FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 30.0,NULL,NULL)
			END

			RETURN
		END
	END

	IF (@DateService < '2016-10-24') --ANTES DEL RFP AVA-2016
	BEGIN
		IF	(	(@CompanyId=38 AND @BillingToCompanyId=1) OR -- TAME A AVA
				(@CompanyId=47 AND @BillingToCompanyId=1 AND @DateService < '2014-09-16') OR -- AEROGAL A AVA
				(@CompanyId=39 AND @BillingToCompanyId=1 AND @DateService < '2014-09-16')	-- INSEL A AVA
			)                         
		BEGIN
			INSERT @Result SELECT * FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 60.0,NULL,NULL)
			RETURN
		END
	END

	--REGLA ANTIGUA
	IF	(	@CompanyId IN (1, 193) AND @AirportId IN (5, 9, 11, 4, 18, 31, 34, 3, 40, 43, 45, 51, 55)	) --AVIANCA S.A / REGIONAL ARRIENDOS ADZ, AXM, BGA, CLO, CUC, IBE, LET, MDE, MTR, NVA, PEI, RCH, SMR
	BEGIN
		RETURN -- NO SE TIENE EN CUENTA LOS AIRES DE ARRIENDO FACTURADOS POR PMO
	END



	--REGLA ANTIGUA
	IF	(	@CompanyId = 42 AND @AirportId <> 11	) --TACA EN TODAS LAS BASES EXCEPTO CLO
	BEGIN
		RETURN -- NO SE TIENE EN CUENTA LOS AIRES DE ARRIENDO FACTURADOS POR PMO
	END



	IF (@CompanyId = 43 AND @BillingToCompanyId = 1) --AMERICAN AIRLINES A AVIANCA                        
	BEGIN
		IF (@ServiceTypeId = 1) --TTO
		BEGIN
			INSERT @Result SELECT * FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 120, 30.0,NULL,NULL)
		END

		IF (@ServiceTypeId IN(2,3)) --PNTA
		BEGIN
			INSERT @Result SELECT * FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 120, 30.0,2,@ServiceHeaderId)
		END

		IF (@ServiceTypeId = 4) --PVLO
		BEGIN
			SELECT	@TimeLeftover = MIN(TimeLeftover)
			FROM	[CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_AdditionalServicesAir](@ServiceHeaderId,
													2,
													@CompanyId,
													@BillingToCompanyId,
													@AirportId,
													@OriginId,
													@DestinationId,
													@DateService,
													@ATA,
													@ATD)

				
			SET @TimeLeftover = ISNULL(@TimeLeftover, 120) --SI NO HAY PERNOCTA
					
			INSERT @Result SELECT * FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, @TimeLeftover, 30.0,4,@ServiceHeaderId)
		END

		IF (@ServiceTypeId NOT IN (1, 2, 3,4))
		BEGIN
			INSERT @Result SELECT * FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 30.0,NULL,NULL)
		END

		RETURN
	END
		
	--SI NO CUMPLE NINGUNA ANTERIOR OTRAS COMPAÑIAS
	INSERT @Result SELECT * FROM [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CalculateSummedTime](@ServiceDetail, 0, 30.0,NULL,NULL)
	RETURN
END